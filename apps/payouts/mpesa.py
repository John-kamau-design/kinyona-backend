import requests
from requests.auth import HTTPBasicAuth
from decouple import config

class MPesaB2CClient:
    def __init__(self):
        self.env = config('MPESA_ENVIRONMENT', default='sandbox')
        self.consumer_key = config('MPESA_CONSUMER_KEY')
        self.consumer_secret = config('MPESA_CONSUMER_SECRET')
        self.shortcode = config('MPESA_SHORTCODE')
        self.initiator_name = config('MPESA_INITIATOR_NAME')
        self.initiator_password = config('MPESA_INITIATOR_PASSWORD')
        self.result_url = config('MPESA_B2C_RESULT_URL')
        self.timeout_url = config('MPESA_B2C_TIMEOUT_URL')

        if self.env == 'production':
            self.base_url = 'https://api.safaricom.co.ke'
        else:
            self.base_url = 'https://sandbox.safaricom.co.ke'

    def get_access_token(self):
        url = f"{self.base_url}/oauth/v1/generate?grant_type=client_credentials"
        response = requests.get(url, auth=HTTPBasicAuth(self.consumer_key, self.consumer_secret))
        response.raise_for_status()
        return response.json().get('access_token')

    def trigger_b2c_payout(self, phone_number, amount, transaction_id, command_id='BusinessPayment'):
        access_token = self.get_access_token()
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        }
        url = f"{self.base_url}/mpesa/b2c/v1/paymentrequest"

        # Format phone to 254XXXXXXXXX
        formatted_phone = phone_number.replace('+', '').strip()
        if formatted_phone.startswith('0'):
            formatted_phone = '254' + formatted_phone[1:]

        payload = {
            "InitiatorName": self.initiator_name,
            "SecurityCredential": self.initiator_password,
            "CommandID": command_id,
            "Amount": int(amount),
            "PartyA": self.shortcode,
            "PartyB": formatted_phone,
            "Remarks": f"Milk Payout Ref: {transaction_id}",
            "QueueTimeOutURL": self.timeout_url,
            "ResultURL": self.result_url,
            "Occasion": "MilkPayout"
        }

        response = requests.post(url, json=payload, headers=headers)
        return response.json()