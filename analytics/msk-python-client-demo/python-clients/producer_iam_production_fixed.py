#!/usr/bin/env python3.8
"""
MSK Producer with IAM Authentication - Production Ready (Fixed)
生产级IAM认证MSK生产者 - 修复版本
"""
import json
import logging
import os
import sys
import time
import signal
from datetime import datetime
from confluent_kafka import Producer, KafkaError
import boto3
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MSKProducerIAM:
    def __init__(self):
        self.bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS_IAM')
        self.topic = os.getenv('MSK_TOPIC', 'msk-poc-topic')
        self.region = os.getenv('AWS_DEFAULT_REGION', 'ap-southeast-1')
        self.producer = None
        self.running = True
        self.messages_sent = 0
        
        if not self.bootstrap_servers:
            raise ValueError("MSK_BOOTSTRAP_SERVERS_IAM environment variable is required")
        
        logger.info(f"Initializing MSK Producer with IAM Authentication")
        logger.info(f"Bootstrap servers: {self.bootstrap_servers}")
        logger.info(f"Topic: {self.topic}")
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

    def create_producer(self):
        """Create Kafka producer with IAM authentication"""
        try:
            # Configuration compatible with confluent-kafka 1.9.2
            config = {
                'bootstrap.servers': self.bootstrap_servers,
                'security.protocol': 'SASL_SSL',
                'sasl.mechanism': 'OAUTHBEARER',
                'oauth_cb': self.oauth_cb,
                'client.id': 'msk-poc-producer-iam',
                'acks': 'all',
                'retries': 3,
                'batch.size': 16384,
                'linger.ms': 10,
                'compression.type': 'snappy',
                'max.in.flight.requests.per.connection': 5,
                'enable.idempotence': True,
                'request.timeout.ms': 30000
            }
            
            self.producer = Producer(config)
            logger.info("Producer created successfully with IAM authentication")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create producer: {e}")
            return False

    def delivery_callback(self, err, msg):
        """Callback for message delivery reports"""
        if err is not None:
            logger.error(f'Message delivery failed: {err}')
        else:
            self.messages_sent += 1
            logger.info(f'Message {self.messages_sent} delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}')

    def produce_messages(self, num_messages=10, interval=1):
        """Produce messages to Kafka topic"""
        if not self.producer:
            logger.error("Producer not initialized")
            return False
        
        try:
            logger.info(f"Starting to produce {num_messages} messages...")
            
            for i in range(num_messages):
                if not self.running:
                    logger.info("Stopping message production due to interrupt")
                    break
                
                # Create message
                message = {
                    'id': i + 1,
                    'timestamp': datetime.now().isoformat(),
                    'message': f'Hello from MSK Producer with IAM Auth - Message {i + 1}',
                    'source': 'msk-poc-producer-iam',
                    'region': self.region,
                    'producer_id': os.getenv('HOSTNAME', 'unknown'),
                    'sequence': i + 1
                }
                
                # Produce message
                try:
                    self.producer.produce(
                        topic=self.topic,
                        key=str(message['id']),
                        value=json.dumps(message, ensure_ascii=False),
                        callback=self.delivery_callback
                    )
                    
                    # Poll for delivery reports
                    self.producer.poll(0)
                    
                    logger.info(f"Queued message {i + 1}/{num_messages}")
                    
                    if interval > 0:
                        time.sleep(interval)
                        
                except Exception as e:
                    logger.error(f"Failed to produce message {i + 1}: {e}")
                    continue
            
            # Wait for all messages to be delivered
            logger.info("Waiting for message delivery confirmation...")
            remaining = self.producer.flush(timeout=30)
            
            if remaining > 0:
                logger.warning(f"{remaining} messages were not delivered")
            else:
                logger.info(f"All {self.messages_sent} messages delivered successfully")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to produce messages: {e}")
            return False

    def signal_handler(self, signum, frame):
        """Handle interrupt signals"""
        logger.info("Received interrupt signal, stopping producer...")
        self.running = False

    def close(self):
        """Close the producer"""
        if self.producer:
            logger.info("Flushing remaining messages...")
            self.producer.flush(timeout=10)
            logger.info("Producer closed")

def main():
    """Main function"""
    logger.info("Starting MSK Producer with IAM Authentication (Production)")
    
    producer = None
    try:
        # Create producer
        producer = MSKProducerIAM()
        
        # Set up signal handler
        signal.signal(signal.SIGINT, producer.signal_handler)
        signal.signal(signal.SIGTERM, producer.signal_handler)
        
        # Initialize producer
        if not producer.create_producer():
            logger.error("Failed to create producer")
            sys.exit(1)
        
        # Produce messages
        success = producer.produce_messages(
            num_messages=int(os.getenv('NUM_MESSAGES', '5')),
            interval=float(os.getenv('MESSAGE_INTERVAL', '1'))
        )
        
        if success:
            logger.info("Producer test completed successfully")
        else:
            logger.error("Producer test failed")
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    except Exception as e:
        logger.error(f"Producer test failed: {e}")
        sys.exit(1)
    finally:
        if producer:
            producer.close()

if __name__ == "__main__":
    main()
