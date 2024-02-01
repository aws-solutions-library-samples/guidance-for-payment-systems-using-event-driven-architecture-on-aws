import json
import requests
import boto3
import os

def lambda_handler(event, context):
    
    print(event)
    eventbridge = boto3.client('events')

    # mock posting api
    mock_api_url = "https://mock-posting.com"
    
    # Get the BUS NAME from Environment
    eb_name = os.environ.get("EVENT_BUS_NAME")

    # Iterate through the SQS messages
    try:
        print(event['Records'])
        for record in event['Records']:
            # Parse the SQS message body as JSON
            #sqs_message = json.loads( json.dumps(record['body']))['detail']
            sqs_message = json.loads(record['body'])
            print(sqs_message)
            #account = sqs_message['Account']
            accountType = sqs_message['detail']['account_type']
            billingAmount = sqs_message['detail']['billingAmount']
            transactionAmount = sqs_message['detail']['transactionAmount']
            issuingCountryCode = sqs_message['detail']['issuingCountryCode']
            conversionRate = sqs_message['detail']['conversionRate']
            merchantType = sqs_message['detail']['merchantType']
            authCode = sqs_message['detail']['authCode']
            suspenseAccount = sqs_message['detail']['suspense_account']
            headOfficeAccount = sqs_message['detail']['head_office_account']
            
            mock_request_data = {
                #'account': account,
                'accountType': accountType,
                'billingAmount': billingAmount,
                'transactionAmount': transactionAmount,
                'issuingCountryCode': issuingCountryCode,
                'conversionRate': conversionRate,
                'merchantType': merchantType,
                'authCode': authCode,
                'suspenseAccount': suspenseAccount,
                'headOfficeAccount': headOfficeAccount
            }
    
    except Exception as e:
        print(e)

    # Lets Pass this to Stuff
    

    # Mock call. Uncomment and call the external API
    #response = requests.post(mock_api_url, json=mock_request_data)

    # Prepare Event for EB
    event_to_send = {
            #'account': account,
            'accountType': accountType,
            'billingAmount': billingAmount,
            'transactionAmount': transactionAmount,
            'issuingCountryCode': issuingCountryCode,
            'conversionRate': conversionRate,
            'merchantType': merchantType,
            'authCode': authCode,
            'suspenseAccount': suspenseAccount,
            'headOfficeAccount': headOfficeAccount
            #,'mock_api_response': response.json()  
        }

    # Send to EB
    eventbridge.put_events(
            Entries=[
                {
                    'Source': 'octank.payments.posting.poster',
                    'DetailType': 'TransactionPosted',
                    'EventBusName': eb_name,
                    'Detail': json.dumps(event_to_send)
                }
            ]
        )

    return {
        'statusCode': 200,
        'body': json.dumps('Lambda execution completed successfully.')
    }
