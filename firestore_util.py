import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("service_account.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def get_product_info(product_id):
    doc = db.collection('products').document(product_id).get()
    return doc.to_dict()
