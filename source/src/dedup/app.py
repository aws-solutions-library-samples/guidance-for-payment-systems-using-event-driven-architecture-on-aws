import json
import time
import os
import boto3
from boto3.dynamodb.conditions import Attr, Or, And
from botocore.exceptions import ClientError

def build_key(transaction):
  '''Build a key from the transaction data'''

  # This should be a hash of the transaction data
  return transaction["authCode"]

def get_exists_lock(transaction, check_time, window_start, window_end):
  key = build_key(transaction)

  # Put an item in dynamodb if it doesn't already exist
  dynamodb = boto3.resource('dynamodb')
  table = dynamodb.Table('transaction_dupcheck_log')
  try:
    response = table.put_item(
      Item={
        'key': key,
        'arrivedAt': check_time,
      },
      
      # TODO: validate windowing logic
      ConditionExpression=Or(Attr('key').not_exists(),Or(Attr('arrivedAt').lt(window_start), Attr('arrivedAt').gt(window_end)))
    )
  except ClientError as err:
    print("Conditional check failed")
    print(err)
    return True

  print('write response:')
  print(response)
  return False

def lambda_handler(event, context):
  """
  Handle inbound lambda invoke event.

  Attempt to get a lock for this transaction within our reprocessing window. 
  If we can't get one, we can consider this transaction to be a duplicate.
  """

  print("Received event: " + json.dumps(event, indent=2))
  now = int(time.time())

  # Get the WINDOW_DURATION environment variable
  window_duration_seconds = int(os.environ.get("WINDOW_DURATION_SECONDS", 300))
  window_start = now - window_duration_seconds
  window_end = now + 5 # arbitrary window

  # Decide if this event is a duplicate or not by trying to get a lock against ddb
  is_dup = get_exists_lock(event[0],check_time=now,window_start=window_start,window_end=window_end)
  #is_dup = random.choice([True, False])
  print("Event is a duplicate: " + str(is_dup))
  
  # Augment event with dupcheck sub-property
  event[0]["dupcheck"] = {"isDuplicate":is_dup,"checkedAt":now, "windowStart":window_start,"windowEnd":window_end}
  return event