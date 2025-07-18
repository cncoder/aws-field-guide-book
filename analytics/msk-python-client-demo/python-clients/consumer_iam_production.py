#!/usr/bin/env python3.8
"""
MSK Consumer with IAM Authentication - Production Ready
生产级IAM认证MSK消费者
"""
import json
import logging
import os
import signal
import sys
import time
from confluent_kafka import Consumer, KafkaError
import boto3
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MSKConsumerIAM:
    def __init__(self):
        self.bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_IAM')
        self.topic = os.getenv('MSK_TOPIC', 'msk-poc-topic')
        self.group_id = os.getenv('MSK_CONSUMER_GROUP', 'msk-poc-consumer-group-iam')
        self.region = os.getenv('AWS_DEFAULT_REGION', 'ap-southeast-1')
        self.consumer = None
        self.running = True
        self.message_count = 0
        
        if not self.bootstrap_servers:
            raise ValueError("MSK_BOOTSTRAP_SERVERS_IAM environment variable is required")
        
        logger.info(f"Initializing MSK Consumer with IAM Authentication")
        logger.info(f"Bootstrap servers: {self.bootstrap_servers}")
        logger.info(f"Topic: {self.topic}")
        logger.info(f"Group ID: {self.group_id}")
        logger.info(f"Region: {self.region}")

    def oauth_cb(self, oauth_config):
        """OAuth callback function for SASL_OAUTHBEARER"""
        try:
            # Create MSK auth token provider
            auth_token_provider = MSKAuthTokenProvider(region=self.region)
            
            # Generate token
            token, expiry_ms = auth_token_provider.generate_auth_token(self.bootstrap_servers)
            
            logger.debug("Successfully generated IAM auth token")
            
            # Set OAuth configuration
            oauth_config.token = token
            oauth_config.principal = "msk-iam-user"
            
        except Exception as e:
            logger.error(f"Failed to generate auth token: {e}")
            raise

    def create_consumer(self):
        """Create Kafka consumer with IAM authentication"""
        try:
            # Configuration compatible with confluent-kafka 1.9.2
            config = {
                'bootstrap.servers': self.bootstrap_servers,
                'security.protocol': 'SASL_SSL',
                'sasl.mechanism': 'OAUTHBEARER',
                'oauth_cb': self.oauth_cb,
                'group.id': self.group_id,
                'client.id': 'msk-poc-consumer-iam',
                'auto.offset.reset': 'earliest',
                'enable.auto.commit': True,
                'auto.commit.interval.ms': 1000,
                'session.timeout.ms': 30000,
                'heartbeat.interval.ms': 10000,
                'max.poll.interval.ms': 300000,
                'fetch.min.bytes': 1
            }
            
            self.consumer = Consumer(config)
            logger.info("Consumer created successfully with IAM authentication")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create consumer: {e}")
            return False

    def subscribe_to_topic(self):
        """Subscribe to Kafka topic"""
        try:
            self.consumer.subscribe([self.topic])
            logger.info(f"Subscribed to topic: {self.topic}")
            return True
        except Exception as e:
            logger.error(f"Failed to subscribe to topic: {e}")
            return False

    def consume_messages(self, timeout=60):
        """Consume messages from Kafka topic"""
        if not self.consumer:
            logger.error("Consumer not initialized")
            return False
        
        logger.info(f"Starting to consume messages for {timeout} seconds...")
        start_time = time.time()
        
        try:
            while self.running and (time.time() - start_time) < timeout:
                msg = self.consumer.poll(timeout=1.0)
                
                if msg is None:
                    continue
                
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        logger.debug(f"Reached end of partition {msg.partition()}")
                    else:
                        logger.error(f"Consumer error: {msg.error()}")
                else:
                    # Process message
                    try:
                        key = msg.key().decode('utf-8') if msg.key() else None
                        value_str = msg.value().decode('utf-8')
                        
                        # Try to parse as JSON
                        try:
                            value = json.loads(value_str)
                        except json.JSONDecodeError:
                            value = value_str
                        
                        self.message_count += 1
                        
                        logger.info(f"Consumed message {self.message_count}:")
                        logger.info(f"  Topic: {msg.topic()}")
                        logger.info(f"  Partition: {msg.partition()}")
                        logger.info(f"  Offset: {msg.offset()}")
                        logger.info(f"  Key: {key}")
                        logger.info(f"  Timestamp: {msg.timestamp()}")
                        
                        if isinstance(value, dict):
                            logger.info(f"  Message ID: {value.get('id', 'N/A')}")
                            logger.info(f"  Message: {value.get('message', 'N/A')}")
                            logger.info(f"  Source: {value.get('source', 'N/A')}")
                        else:
                            logger.info(f"  Value: {value}")
                        
                        logger.info("  " + "-" * 50)
                        
                    except Exception as e:
                        logger.error(f"Error processing message: {e}")
                        logger.info(f"Raw message: {msg.value()}")
            
            logger.info(f"Consumed {self.message_count} messages in total")
            return True
            
        except KeyboardInterrupt:
            logger.info("Received interrupt signal, stopping consumer...")
            return True
        except Exception as e:
            logger.error(f"Failed to consume messages: {e}")
            return False

    def signal_handler(self, signum, frame):
        """Handle interrupt signals"""
        logger.info("Received interrupt signal, stopping consumer...")
        self.running = False

    def close(self):
        """Close the consumer"""
        if self.consumer:
            try:
                self.consumer.close()
                logger.info("Consumer closed")
            except Exception as e:
                logger.error(f"Error closing consumer: {e}")

def main():
    """Main function"""
    logger.info("Starting MSK Consumer with IAM Authentication (Production)")
    
    consumer = None
    try:
        # Create consumer
        consumer = MSKConsumerIAM()
        
        # Set up signal handler
        signal.signal(signal.SIGINT, consumer.signal_handler)
        signal.signal(signal.SIGTERM, consumer.signal_handler)
        
        # Initialize consumer
        if not consumer.create_consumer():
            logger.error("Failed to create consumer")
            sys.exit(1)
        
        # Subscribe to topic
        if not consumer.subscribe_to_topic():
            logger.error("Failed to subscribe to topic")
            sys.exit(1)
        
        # Consume messages
        timeout = int(os.getenv('CONSUME_TIMEOUT', '30'))
        success = consumer.consume_messages(timeout=timeout)
        
        if success:
            logger.info("Consumer test completed successfully")
        else:
            logger.error("Consumer test failed")
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    except Exception as e:
        logger.error(f"Consumer test failed: {e}")
        sys.exit(1)
    finally:
        if consumer:
            consumer.close()

if __name__ == "__main__":
    main()
