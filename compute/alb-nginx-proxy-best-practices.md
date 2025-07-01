# AWS ALB + Nginx 代理配置最佳实践

解决项目上线时 Nginx 代理 AWS ALB 可能遇到的连接问题和配置优化方案。

## 📋 问题背景

在使用 Nginx 作为网关代理 AWS ALB 时，经常会遇到以下问题：
- 偶发性连接错误，但后端服务实际运行正常
- 间歇性的 502/504 错误
- 负载均衡器扩缩容时出现连接中断

这些问题主要由 ALB 的动态特性与 Nginx 默认 DNS 解析行为不匹配导致。

## 🔍 原因分析

### ALB 特性
- **动态 IP 地址**: ALB 的 IP 地址会根据流量、维护、扩缩容等场景动态变化
- **DNS TTL**: ALB 使用 VPC DNS 服务，DNS TTL 设置为 60 秒
- **高可用性**: 为保证高可用，AWS 会定期更新 ALB 的 IP 地址

### Nginx 默认行为
- **静态 DNS 解析**: 默认只在启动时解析一次 DNS
- **IP 缓存**: 解析后会持续使用缓存的 IP 地址
- **连接失败**: 当 ALB IP 变化时，继续使用旧 IP 会导致连接超时

## ✅ 解决方案

### 1. 配置动态 DNS 解析

```nginx
http {
    # 使用 VPC DNS 服务器 (VPC CIDR + 2)
    resolver 10.0.0.2 valid=30s ipv6=off;
    resolver_timeout 5s;
    
    # 定义 ALB 后端
    upstream alb_backend {
        server your-alb-name.region.elb.amazonaws.com resolve;
        keepalive 32;
        keepalive_requests 100;
        keepalive_timeout 60s;
    }

    server {
        listen 80;
        server_name your-domain.com;
        
        # 错误和访问日志
        error_log /var/log/nginx/alb_proxy_error.log warn;
        access_log /var/log/nginx/alb_proxy_access.log;
        
        location / {
            proxy_pass http://alb_backend;
            
            # HTTP 版本和连接设置
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            
            # 传递客户端信息
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # 超时设置
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # 重试机制
            proxy_next_upstream error timeout http_502 http_503 http_504;
            proxy_next_upstream_tries 3;
            proxy_next_upstream_timeout 10s;
        }
        
        # 健康检查端点
        location /nginx-health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

### 2. 关键配置说明

| 配置项 | 推荐值 | 说明 |
|--------|--------|------|
| `resolver valid` | 10-30s | DNS 解析缓存时间，不应超过 ALB DNS TTL (60s) |
| `resolver_timeout` | 5s | DNS 解析超时时间 |
| `keepalive` | 32 | 连接池大小，提升性能 |
| `proxy_next_upstream_tries` | 3 | 重试次数 |
| `proxy_connect_timeout` | 5s | 连接超时时间 |

### 3. VPC DNS 服务器配置

确定你的 VPC DNS 服务器地址：

```bash
# VPC CIDR 示例对应的 DNS 服务器
# 10.0.0.0/16  -> 10.0.0.2
# 172.31.0.0/16 -> 172.31.0.2
# 192.168.0.0/16 -> 192.168.0.2

# 查看当前 VPC DNS 设置
aws ec2 describe-vpcs --vpc-ids vpc-xxxxxxxxx \
  --query 'Vpcs[0].CidrBlock' --output text
```

## 📊 监控与排查

### 1. 启用 ALB 访问日志

```bash
# 创建 S3 存储桶用于存储访问日志
aws s3 mb s3://your-alb-access-logs-bucket

# 启用 ALB 访问日志
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:region:account:loadbalancer/app/your-alb/xxx \
  --attributes Key=access_logs.s3.enabled,Value=true \
              Key=access_logs.s3.bucket,Value=your-alb-access-logs-bucket \
              Key=access_logs.s3.prefix,Value=alb-logs
```

### 2. Nginx 日志配置

```nginx
# 详细的日志格式
log_format alb_proxy '$remote_addr - $remote_user [$time_local] '
                     '"$request" $status $body_bytes_sent '
                     '"$http_referer" "$http_user_agent" '
                     'upstream_addr=$upstream_addr '
                     'upstream_status=$upstream_status '
                     'upstream_response_time=$upstream_response_time '
                     'request_time=$request_time';

access_log /var/log/nginx/alb_proxy.log alb_proxy;
error_log /var/log/nginx/alb_proxy_error.log warn;
```

### 3. 监控脚本

```bash
#!/bin/bash
# monitor_alb_nginx.sh - 监控 ALB 和 Nginx 连接状态

# 检查 ALB DNS 解析
echo "=== ALB DNS Resolution ==="
nslookup your-alb-name.region.elb.amazonaws.com

# 检查 Nginx 错误日志
echo "=== Recent Nginx Errors ==="
tail -20 /var/log/nginx/alb_proxy_error.log

# 检查连接状态
echo "=== Connection Status ==="
netstat -an | grep :80 | head -10

# 检查 Nginx 进程
echo "=== Nginx Process ==="
ps aux | grep nginx
```

## 🚀 性能优化建议

### 1. 连接池优化

```nginx
upstream alb_backend {
    server your-alb-name.region.elb.amazonaws.com resolve;
    
    # 连接池配置
    keepalive 32;                    # 保持连接数
    keepalive_requests 1000;         # 每个连接最大请求数
    keepalive_timeout 60s;           # 连接保持时间
    
    # 负载均衡方法
    least_conn;                      # 最少连接数算法
}
```

### 2. 缓存配置

```nginx
# 启用代理缓存
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=alb_cache:10m 
                 max_size=1g inactive=60m use_temp_path=off;

location / {
    proxy_pass http://alb_backend;
    
    # 缓存配置
    proxy_cache alb_cache;
    proxy_cache_valid 200 302 10m;
    proxy_cache_valid 404 1m;
    proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
    
    # 缓存头信息
    add_header X-Cache-Status $upstream_cache_status;
}
```

### 3. 安全配置

```nginx
# 限制请求频率
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

server {
    # 应用限流
    limit_req zone=api burst=20 nodelay;
    
    # 隐藏 Nginx 版本
    server_tokens off;
    
    # 安全头
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
```

## 🔧 故障排查清单

### 常见问题诊断

1. **DNS 解析问题**
   ```bash
   # 测试 DNS 解析
   dig @10.0.0.2 your-alb-name.region.elb.amazonaws.com
   
   # 检查 resolver 配置
   nginx -T | grep resolver
   ```

2. **连接超时问题**
   ```bash
   # 检查网络连通性
   telnet your-alb-name.region.elb.amazonaws.com 80
   
   # 查看连接状态
   ss -tuln | grep :80
   ```

3. **配置验证**
   ```bash
   # 验证 Nginx 配置
   nginx -t
   
   # 重载配置
   nginx -s reload
   ```

## 📋 部署检查清单

- [ ] 确认 VPC DNS 服务器地址配置正确
- [ ] 设置合适的 DNS 缓存时间 (10-30s)
- [ ] 配置连接池和重试机制
- [ ] 启用详细的访问和错误日志
- [ ] 设置监控和告警
- [ ] 测试 ALB IP 变化场景
- [ ] 验证健康检查端点
- [ ] 配置适当的超时时间

## 📚 参考资源

- [AWS ALB 用户指南](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS ALB 访问日志](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)
- [Nginx 代理模块文档](http://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Nginx Upstream 模块](http://nginx.org/en/docs/http/ngx_http_upstream_module.html)

---

通过以上配置，可以有效解决 ALB IP 变化导致的连接问题，同时保持良好的性能表现和系统稳定性。
