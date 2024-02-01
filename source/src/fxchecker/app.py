import json

def lambda_handler(event, context):
    # TODO implement
    
    requestBody = event['body']
    print(requestBody)
    isForeignTransaction = checkRequest(requestBody)
    jsonField = {"isForeignTransaction":isForeignTransaction}
    
    print(isForeignTransaction)
    # parsing JSON string:
    #jsonResponse = json.loads(requestBody)
    
    # appending the data
    requestBody.update(jsonField)
    
    return {
        'statusCode': 200,
        'body': requestBody
    }

def checkRequest(data):
    conversionRate = float(data['conversionRate'])
    billingAmount = float(data['billingAmount'])
    transactionAmount = float(data['transactionAmount'])
    isForeignTransaction = False
    
    print('billingAmount {}'.format(billingAmount))
    print('transactionAmount {}'.format(transactionAmount))
    print('isForeignTransaction {}'.format(isForeignTransaction))
    
    if billingAmount != transactionAmount and conversionRate != 1:
        isForeignTransaction = True
    return isForeignTransaction