import json
import boto3
import random
import string
import os

print('Starting Enrichment')


def lambda_handler(event, context):
    #print("Received event: " + json.dumps(event, indent=2))
    print("Received event: " + json.dumps(event, indent=2))
    enriched_event = process_event(event)
    print("Enriched Event:", enriched_event)
    
def process_event(event):
    pan = event.get("detail", {}).get("PAN", "")
    bilamt = event.get("detail", {}).get("billingAmount", "")
    tranamt = event.get("detail", {}).get("transactionAmount", "")
    conrate = event.get("detail", {}).get("conversionRate", "")
    merctype = event.get("detail", {}).get("merchantType", "")
    issuingCountryCode = event.get("detail", {}).get("issuingCountryCode", "")
    authCode = event.get("detail", {}).get("authCode", "")
    acquiringCountryCode = event.get("detail", {}).get("acquiringCountryCode", "")
    posEntryMode = event.get("detail", {}).get("posEntryMode", "")
    systemTraceAuditNumber = event.get("detail", {}).get("systemTraceAuditNumber", "")
    #pan = event["PAN"]
    
    if pan:
        bank_sort_code, account_number = get_sort_code_and_account(pan)
        iban = get_iban(bank_sort_code, account_number)
        account_type = determine_account_type(bank_sort_code, account_number)
        holds = check_account_holds(account_type, bank_sort_code, account_number)
        suspense_account, head_office_account = get_accounts(account_type)
        tax_category = get_tax_category(account_type)
        enriched_event = create_enriched_event(pan, 
                                               iban, 
                                               account_type, 
                                               holds, suspense_account, 
                                               head_office_account, 
                                               tax_category, 
                                               bilamt, 
                                               tranamt,
                                               conrate,
                                               merctype,
                                               issuingCountryCode,
                                               authCode,
                                               acquiringCountryCode,
                                               posEntryMode,
                                               systemTraceAuditNumber)
        publish_response = publish_event_to_eventbridge(enriched_event)
        return publish_response
        
    else:
        return "No PAN found in the event."

#Pass the PAN and in return get the Branch & Account#
def get_sort_code_and_account(pan):
    sort_code = ''.join(random.choice(string.digits) for _ in range(6))
    acct_number = ''.join(random.choice(string.digits) for _ in range(6))
    return sort_code, acct_number

def get_iban(bank_sort_code, account_number):
    #If we want we can use a rand of GB, US, etc, but for now limiting to GB!!!
    return "GB" + bank_sort_code + account_number

def determine_account_type(bank_sort_code, account_number):
    
    account_types = ["Savings", "Checking", "Business"]
    return random.choice(account_types)

def check_account_holds(account_type, bank_sort_code, account_number):
    
    return random.choice([True, False])

def get_accounts(account_type):
    suspense_account = "SA" + ''.join(random.choice(string.digits) for _ in range(6))
    head_office_account = "HO" + ''.join(random.choice(string.digits) for _ in range(6))
    return suspense_account, head_office_account

def get_tax_category(account_type):
    tax_categories = ["Personal", "Business", "Corporation", "Other"]
    return random.choice(tax_categories)

def create_enriched_event(original_message, iban, account_type, holds, suspense_account, head_office_account, tax_category, bilamt, tranamt, conrate, merctype,
                                issuingCountryCode,authCode,acquiringCountryCode,posEntryMode,systemTraceAuditNumber):
    # Combine the enriched data
    enriched_data = {
        "original_message": original_message,
        "iban": iban,
        "account_type": account_type,
        "has_holds": holds,
        "suspense_account": suspense_account,
        "head_office_account": head_office_account,
        "tax_category": tax_category,
        "billingAmount": bilamt,
        "transactionAmount": tranamt,
        "conversionRate": conrate,
        "merchantType": merctype,
        "issuingCountryCode": issuingCountryCode,
        "authCode": authCode,
        "acquiringCountryCode": acquiringCountryCode,
        "posEntryMode": posEntryMode,
        "systemTraceAuditNumber": systemTraceAuditNumber
    }
    return json.dumps(enriched_data)
    



def publish_event_to_eventbridge(event):
    event_bridge_client = boto3.client("events")
    event_bus_name = os.environ.get("EVENT_BUS_NAME")
    detail_type = "TransactionEnriched"
    print(event)
    try:
        response = event_bridge_client.put_events(
            Entries=[
                {
                    "Source": "octank.payments.posting.enrichment",
                    "DetailType": detail_type,
                    "EventBusName": event_bus_name,
                    "Detail": event,
                }
            ]
        )
    except botocore.exceptions.ClientError as error:
        raise error
    
    return response


