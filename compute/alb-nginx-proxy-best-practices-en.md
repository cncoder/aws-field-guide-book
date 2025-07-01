# AWS ALB + Nginx Proxy Configuration Best Practices

Solving connection issues and configuration optimization when using Nginx as a reverse proxy for AWS ALB during project deployment.

[中文版本](alb-nginx-proxy-best-practices.md)

## 📋 Problem Background

When using Nginx as a reverse proxy to forward requests to AWS ALB during project deployment, you may encounter the following symptoms:

- **Intermittent connection failures**: Occasional 502/504 errors while ALB backend services are running normally
- **Periodic failures**: Brief connection issues occurring every 1-2 hours
- **Interruptions during scaling**: Connection drops during peak traffic or ALB auto-scaling events
- **Recovery after Nginx restart**: Issues temporarily resolve after restarting Nginx service

The root cause of these symptoms is a **mismatch between Nginx's DNS resolution mechanism and ALB's dynamic characteristics**:

### Technical Root Cause Analysis

**ALB's Dynamic Nature** (This is ALB's normal behavior):
- ALB automatically adjusts its IP addresses based on traffic changes, availability zone health, maintenance needs, etc.
- ALB's DNS record TTL is set to 60 seconds, meaning IP addresses may update every minute
- This dynamic behavior is core to ALB's high availability and elastic scaling features

**Nginx's Default DNS Behavior**:
- Nginx resolves domain names to IP addresses at startup and caches these IPs
- By default, Nginx doesn't re-resolve domain names and continues using startup-cached IPs
- When ALB's IP changes, Nginx still sends requests to old IPs, causing connection failures

## 💡 Solution Overview

The core approach to solving this issue is: **Enable Nginx to dynamically resolve ALB domain names** instead of relying on static IP caches from startup.

Main approaches include:
1. **Configure VPC DNS Server**: Ensure Nginx uses the correct DNS server
2. **Enable Dynamic DNS Resolution**: Configure Nginx to periodically re-resolve ALB domain names
3. **Set Appropriate Cache Time**: Balance resolution frequency and performance overhead
4. **Add Retry Mechanism**: Improve system fault tolerance

## 🔧 Detailed Configuration Steps

### Step 1: Determine VPC DNS Server Address

First, you need to determine your VPC DNS server address. AWS VPC DNS server address follows the rule: **The second IP address of VPC CIDR**.

```bash
# Check your VPC CIDR
aws ec2 describe-vpcs --vpc-ids vpc-xxxxxxxxx \
  --query 'Vpcs[0].CidrBlock' --output text

# Common VPC CIDR to DNS server mappings:
# 10.0.0.0/16     -> DNS: 10.0.0.2
# 172.31.0.0/16   -> DNS: 172.31.0.2  
# 192.168.0.0/16  -> DNS: 192.168.0.2
```

### Step 2: Configure Nginx Dynamic DNS Resolution

```nginx
http {
    # Configure DNS resolver (use your VPC DNS server)
    resolver 10.0.0.2 valid=30s ipv6=off;
    resolver_timeout 5s;
    
    # Define ALB backend, note the resolve parameter
    upstream alb_backend {
        server your-alb-name.region.elb.amazonaws.com resolve;
        keepalive 32;
        keepalive_requests 100;
        keepalive_timeout 60s;
    }

    server {
        listen 80;
        server_name your-domain.com;
        
        location / {
            proxy_pass http://alb_backend;
            
            # Basic proxy settings
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeout and retry settings
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            proxy_next_upstream error timeout http_502 http_503 http_504;
            proxy_next_upstream_tries 3;
            proxy_next_upstream_timeout 10s;
        }
    }
}
```

### Step 3: Key Configuration Parameters

| Parameter | Recommended Value | Description |
|-----------|-------------------|-------------|
| `resolver` | Your VPC DNS IP | Specify DNS server address |
| `valid=30s` | 10-30 seconds | DNS resolution cache time, don't exceed 60s |
| `resolve` | Must add | Key parameter to enable dynamic DNS resolution |
| `keepalive 32` | 16-64 | Connection pool size for performance |
| `proxy_next_upstream_tries` | 2-3 times | Number of retry attempts |

### Step 4: Verify Configuration

```bash
# 1. Check configuration syntax
nginx -t

# 2. Reload configuration
nginx -s reload

# 3. Test DNS resolution
dig @10.0.0.2 your-alb-name.region.elb.amazonaws.com

# 4. Verify connectivity
curl -I http://your-domain.com
```

## 📊 Monitoring and Troubleshooting (Optional)

If you need deep insights into system performance or troubleshooting, you can configure the following monitoring solutions:

### Optional: Enable Detailed Logging

```nginx
# Custom log format including upstream server info
log_format alb_proxy '$remote_addr - $remote_user [$time_local] '
                     '"$request" $status $body_bytes_sent '
                     'upstream_addr=$upstream_addr '
                     'upstream_status=$upstream_status '
                     'upstream_response_time=$upstream_response_time '
                     'request_time=$request_time';

server {
    # Apply custom log format
    access_log /var/log/nginx/alb_proxy.log alb_proxy;
    error_log /var/log/nginx/alb_proxy_error.log warn;
}
```

### Optional: ALB Access Logs

If you need to analyze issues from the ALB layer:

```bash
# Create S3 bucket
aws s3 mb s3://your-alb-logs-bucket

# Enable ALB access logs
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:region:account:loadbalancer/app/your-alb/xxx \
  --attributes Key=access_logs.s3.enabled,Value=true \
              Key=access_logs.s3.bucket,Value=your-alb-logs-bucket
```

### Optional: Monitoring Script

```bash
#!/bin/bash
# Simple connection status check script

echo "=== Current ALB DNS Resolution ==="
nslookup your-alb-name.region.elb.amazonaws.com

echo "=== Nginx Error Log (Last 10 entries) ==="
tail -10 /var/log/nginx/error.log

echo "=== Connection Test ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Total Time: %{time_total}s\n" \
  http://your-domain.com
```

## 🚀 Performance Optimization (Optional)

If your application has high-performance requirements, consider these optimizations:

### Connection Pool Optimization

```nginx
upstream alb_backend {
    server your-alb-name.region.elb.amazonaws.com resolve;
    
    # Adjust based on your concurrency needs
    keepalive 64;                    # Number of keepalive connections
    keepalive_requests 1000;         # Max requests per connection
    keepalive_timeout 60s;           # Connection keepalive time
}
```

### Caching Configuration

```nginx
# If your content is suitable for caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=alb_cache:10m 
                 max_size=1g inactive=60m;

location / {
    proxy_cache alb_cache;
    proxy_cache_valid 200 302 10m;
    proxy_cache_valid 404 1m;
    # Other configurations...
}
```

## 🔧 Common Issue Troubleshooting

### Issue 1: Still Getting Connection Errors After Configuration

**Troubleshooting Steps**:
```bash
# 1. Confirm DNS server address is correct
dig @10.0.0.2 your-alb-name.region.elb.amazonaws.com

# 2. Check Nginx configuration syntax
nginx -t

# 3. Check error logs
tail -f /var/log/nginx/error.log
```

### Issue 2: DNS Resolution Timeout

**Possible Cause**: Incorrect VPC DNS server address configuration

**Solution**:
```bash
# Re-confirm VPC CIDR
aws ec2 describe-vpcs --vpc-ids vpc-xxxxxxxxx

# Ensure security groups allow DNS queries (UDP port 53)
```

### Issue 3: Performance Degradation

**Cause**: DNS resolution frequency too high

**Adjustment**:
```nginx
# Appropriately increase cache time
resolver 10.0.0.2 valid=60s ipv6=off;
```

## 📋 Quick Deployment Checklist

Before deployment, please confirm:

- [ ] Determined correct VPC DNS server address
- [ ] Added `resolve` parameter in upstream configuration
- [ ] Set reasonable DNS cache time (10-60 seconds)
- [ ] Configured appropriate retry mechanism
- [ ] Verified configuration syntax with `nginx -t`
- [ ] Tested DNS resolution works properly
- [ ] Verified application access is normal

## 💡 Summary

The core of this configuration solution is to enable Nginx to **dynamically adapt to ALB's IP changes** rather than treating it as a problem. By properly configuring DNS resolver and enabling dynamic resolution, your application can maintain stable operation during ALB scaling or maintenance.

Remember: ALB's dynamic IP changes are a manifestation of its high availability features. What we need to do is make Nginx's configuration match this characteristic.

## 📚 Reference Resources

- [AWS ALB User Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS ALB Access Logs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)
- [Nginx Proxy Module Documentation](http://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Nginx Upstream Module](http://nginx.org/en/docs/http/ngx_http_upstream_module.html)

---

Through the above configuration, you can effectively resolve connection issues caused by ALB IP changes while maintaining good performance and system stability.
