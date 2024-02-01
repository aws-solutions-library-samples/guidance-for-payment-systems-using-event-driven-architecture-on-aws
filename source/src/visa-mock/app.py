import boto3
import time
import csv
import json
import os

# Initialize the DynamoDB resource
region = os.environ.get('AWS_REGION')
dynamodb = boto3.resource('dynamodb', region_name = region)

# Reference the 'visa' table
table = dynamodb.Table('visa')

def lambda_handler(event, context):
    
    with open('visa_messages.csv', newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            raw_message = row['message']
            unpacked_message = unpack_visa_base1_message(raw_message)
            store_visa_data_in_dynamodb(unpacked_message)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
    
def unpack_visa_base1_message(message):
    try:
        binary_data = bytes.fromhex(message)

        # Sample field lengths based on the VISA BASE I specification
        field_lengths = {
            'Message': 2,
            'Bitmap1': 4,
            'Bitmap2': 4,
            'Bitmap3': 4,
            'MessageType': 2,
            'PAN': 8,
            'ProcessingCode': 3,
            'TransactionAmount': 6,
            'BillingAmount': 6,
            'DateAndTime': 4,
            'ConversionRate': 1,
            'SystemTraceAuditNumber': 6,
            'ExpiryDate': 4,
            'MerchantType': 2,
            'AcquiringCountryCode': 2,
            'IssuingCountryCode': 2,
            'POSEntryMode': 2,
            'PANSequenceNumber': 2,
            'POSConditionCode': 2,
            'AcquiringInstitutionIDCode': 2,
            'ForwardingInstitutionIDCode': 2,
        }

        # Unpack the fields from the binary data
        unpacked_message = {}
        current_position = 0
        for field, length in field_lengths.items():
            field_data = binary_data[current_position : current_position + length]
            unpacked_message[field] = field_data.hex().upper()
            current_position += length

        return unpacked_message

    except Exception as e:
        print(f"Error decoding the message: {e}")
        return None
    
    #Write the Stuff in DynamoDB        
def store_visa_data_in_dynamodb(data):
    
    auth_timestamp = str(int(time.time() * 1000000))
    
    try:
        item = {key: value for key, value in data.items()}
        item['auth'] = auth_timestamp
        table.put_item(Item=item)
        
    except Exception as e:
        print("Error storing the item in DynamoDB:", e)



    
