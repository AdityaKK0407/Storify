from chat_engine import chat_with_model
from firestore_util import get_product_info

def chat_with_firestore_context(user_prompt, product_id):
    product = get_product_info(product_id)
    prompt = f"User asked: {user_prompt}\nProduct info: {product}\nRespond accordingly:"
    return chat_with_model(prompt)
