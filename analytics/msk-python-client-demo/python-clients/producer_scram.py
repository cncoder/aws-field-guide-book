#!/usr/bin/env python3
"""
MSK Producer with SASL/SCRAM Authentication
"""
import json
import logging
import sys
import time
from datetime import datetime
from confluent_kafka import Producer
import boto3

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MSKProducerSCRAM:
    def __init__(self, bootstrap_servers, topic_name, username, password, region='ap-southeast-1'):
        self.bootstrap_servers = bootstrap_servers
        self.topic_name = topic_name
        self.username = username
        self.password = password
        self.region = region
        self.producer = None
        
    def create_producer(self):
        """Create Kafka producer with SASL/SCRAM authentication"""
        try:
            # Producer configuration for SASL/SCRAM authentication
            config = {
                'bootstrap.servers': self.bootstrap_servers,
                'security.protocol': 'SASL_SSL',
                'sasl.mechanisms': 'SCRAM-SHA-512',
                'sasl.username': self.username,
                'sasl.password': self.password,
                'client.id': 'msk-producer-scram',
                'acks': 'all',
                'retries': 3,
                'retry.backoff.ms': 1000,
                'request.timeout.ms': 30000,
                'delivery.timeout.ms': 60000,
                'batch.size': 16384,
                'linger.ms': 10,
                'compression.type': 'snappy'
            }
            
            self.producer = Producer(config)
            logger.info("Producer created successfully with SASL/SCRAM authentication")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create producer: {e}")
            return False
    
    def delivery_callback(self, err, msg):
        """Callback for message delivery reports"""
        if err is not None:
            logger.error(f'Message delivery failed: {err}')
        else:
            logger.info(f'Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}')
    
    def produce_messages(self, num_messages=10, message_interval=1):
        """Produce messages to Kafka topic"""
        if not self.producer:
            logger.error("Producer not initialized")
            return False
            
        try:
            for i in range(num_messages):
                # Create message payload
                message_data = {
                    'message_id': i + 1,
                    'timestamp': datetime.now().isoformat(),
                    'content': f'Test message {i + 1} from SCRAM producer',
                    'producer_type': 'SCRAM',
                    'region': self.region
                }
                
                message_json = json.dumps(message_data)
                
                # Produce message
                self.producer.produce(
                    topic=self.topic_name,
                    key=f'scram-key-{i + 1}',
                    value=message_json,
                    callback=self.delivery_callback
                )
                
                logger.info(f"Produced message {i + 1}: {message_data['content']}")
                
                # Poll for delivery reports
                self.producer.poll(0)
                
                if i < num_messages - 1:
                    time.sleep(message_interval)
            
            # Wait for all messages to be delivered
            self.producer.flush(timeout=30)
            logger.info(f"Successfully produced {num_messages} messages")
            return True
            
        except Exception as e:
            logger.error(f"Error producing messages: {e}")
            return False
    
    def close(self):
        """Close the producer"""
        if self.producer:
            self.producer.flush()
            logger.info("Producer closed")

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

def main():
    """Main function"""
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
    
    logger.info("Starting MSK Producer with SASL/SCRAM Authentication")
    logger.info(f"Bootstrap servers: {bootstrap_servers}")
    logger.info(f"Topic: {topic_name}")
    logger.info(f"Username: {username}")
    
    # Create and run producer
    producer = MSKProducerSCRAM(bootstrap_servers, topic_name, username, password)
    
    try:
        if producer.create_producer():
            success = producer.produce_messages(num_messages=5, message_interval=2)
            if success:
                logger.info("Producer test completed successfully")
            else:
                logger.error("Producer test failed")
                sys.exit(1)
        else:
            logger.error("Failed to create producer")
            sys.exit(1)
            
    except KeyboardInterrupt:
        logger.info("Producer interrupted by user")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)
    finally:
        producer.close()

if __name__ == "__main__":
    main()
