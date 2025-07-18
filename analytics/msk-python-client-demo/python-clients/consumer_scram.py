#!/usr/bin/env python3
"""
MSK Consumer with SASL/SCRAM Authentication
"""
import json
import logging
import sys
import signal
import time
from confluent_kafka import Consumer, KafkaError
import boto3

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MSKConsumerSCRAM:
    def __init__(self, bootstrap_servers, topic_name, group_id, username, password, region='ap-southeast-1'):
        self.bootstrap_servers = bootstrap_servers
        self.topic_name = topic_name
        self.group_id = group_id
        self.username = username
        self.password = password
        self.region = region
        self.consumer = None
        self.running = True
        
    def create_consumer(self):
        """Create Kafka consumer with SASL/SCRAM authentication"""
        try:
            # Consumer configuration for SASL/SCRAM authentication
            config = {
                'bootstrap.servers': self.bootstrap_servers,
                'security.protocol': 'SASL_SSL',
                'sasl.mechanisms': 'SCRAM-SHA-512',
                'sasl.username': self.username,
                'sasl.password': self.password,
                'group.id': self.group_id,
                'client.id': 'msk-consumer-scram',
                'auto.offset.reset': 'earliest',
                'enable.auto.commit': True,
                'auto.commit.interval.ms': 5000,
                'session.timeout.ms': 30000,
                'heartbeat.interval.ms': 10000,
                'max.poll.interval.ms': 300000,
                'fetch.min.bytes': 1,
                'fetch.wait.max.ms': 500
            }
            
            self.consumer = Consumer(config)
            logger.info("Consumer created successfully with SASL/SCRAM authentication")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create consumer: {e}")
            return False
    
    def consume_messages(self, timeout=60):
        """Consume messages from Kafka topic"""
        if not self.consumer:
            logger.error("Consumer not initialized")
            return False
            
        try:
            # Subscribe to topic
            self.consumer.subscribe([self.topic_name])
            logger.info(f"Subscribed to topic: {self.topic_name}")
            
            message_count = 0
            start_time = time.time()
            
            while self.running and (time.time() - start_time) < timeout:
                try:
                    # Poll for messages
                    msg = self.consumer.poll(timeout=1.0)
                    
                    if msg is None:
                        continue
                        
                    if msg.error():
                        if msg.error().code() == KafkaError._PARTITION_EOF:
                            logger.info(f"Reached end of partition {msg.partition()}")
                        else:
                            logger.error(f"Consumer error: {msg.error()}")
                        continue
                    
                    # Process message
                    message_count += 1
                    key = msg.key().decode('utf-8') if msg.key() else None
                    value = msg.value().decode('utf-8') if msg.value() else None
                    
                    logger.info(f"Received message {message_count}:")
                    logger.info(f"  Topic: {msg.topic()}")
                    logger.info(f"  Partition: {msg.partition()}")
                    logger.info(f"  Offset: {msg.offset()}")
                    logger.info(f"  Key: {key}")
                    
                    # Try to parse JSON value
                    try:
                        message_data = json.loads(value)
                        logger.info(f"  Message: {message_data}")
                    except json.JSONDecodeError:
                        logger.info(f"  Value: {value}")
                    
                    logger.info("-" * 50)
                    
                except KeyboardInterrupt:
                    logger.info("Consumer interrupted by user")
                    break
                except Exception as e:
                    logger.error(f"Error consuming message: {e}")
                    continue
            
            logger.info(f"Consumed {message_count} messages in total")
            return True
            
        except Exception as e:
            logger.error(f"Error in consume_messages: {e}")
            return False
    
    def stop(self):
        """Stop the consumer"""
        self.running = False
    
    def close(self):
        """Close the consumer"""
        if self.consumer:
            self.consumer.close()
            logger.info("Consumer closed")

def get_scram_credentials():
    """Get SCRAM credentials from AWS Secrets Manager"""
    try:
        import os
        secret_name = os.environ.get('MSK_SCRAM_SECRET_NAME', 'msk-poc-msk-scram-credentials')
        region = os.environ.get('AWS_DEFAULT_REGION', 'ap-southeast-1')
        
        # Create a Secrets Manager client
        session = boto3.session.Session()
        client = session.client(
            service_name='secretsmanager',
            region_name=region
        )
        
        # Get the secret value
        response = client.get_secret_value(SecretId=secret_name)
        secret = json.loads(response['SecretString'])
        
        return secret['username'], secret['password']
        
    except Exception as e:
        logger.error(f"Error getting SCRAM credentials: {e}")
        return None, None

def get_msk_bootstrap_servers():
    """Get MSK bootstrap servers from environment"""
    try:
        import os
        bootstrap_servers = os.environ.get('MSK_BOOTSTRAP_SERVERS_SCRAM')
        if bootstrap_servers:
            return bootstrap_servers
            
        logger.warning("MSK_BOOTSTRAP_SERVERS_SCRAM not found in environment")
        logger.info("Please set MSK_BOOTSTRAP_SERVERS_SCRAM environment variable")
        return None
        
    except Exception as e:
        logger.error(f"Error getting bootstrap servers: {e}")
        return None

def signal_handler(signum, frame):
    """Handle interrupt signals"""
    logger.info("Received interrupt signal, stopping consumer...")
    global consumer_instance
    if consumer_instance:
        consumer_instance.stop()

def main():
    """Main function"""
    global consumer_instance
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Get bootstrap servers
    bootstrap_servers = get_msk_bootstrap_servers()
    if not bootstrap_servers:
        logger.error("Bootstrap servers not available")
        sys.exit(1)
    
    # Get SCRAM credentials
    username, password = get_scram_credentials()
    if not username or not password:
        logger.error("SCRAM credentials not available")
        sys.exit(1)
    
    topic_name = "msk-poc-topic"
    group_id = "msk-poc-consumer-group-scram"
    
    logger.info("Starting MSK Consumer with SASL/SCRAM Authentication")
    logger.info(f"Bootstrap servers: {bootstrap_servers}")
    logger.info(f"Topic: {topic_name}")
    logger.info(f"Group ID: {group_id}")
    logger.info(f"Username: {username}")
    
    # Create and run consumer
    consumer_instance = MSKConsumerSCRAM(bootstrap_servers, topic_name, group_id, username, password)
    
    try:
        if consumer_instance.create_consumer():
            success = consumer_instance.consume_messages(timeout=120)
            if success:
                logger.info("Consumer test completed successfully")
            else:
                logger.error("Consumer test failed")
                sys.exit(1)
        else:
            logger.error("Failed to create consumer")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)
    finally:
        consumer_instance.close()

# Global variable for signal handler
consumer_instance = None

if __name__ == "__main__":
    main()
