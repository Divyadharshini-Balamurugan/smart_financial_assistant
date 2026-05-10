import firebase_admin
from firebase_admin import credentials, firestore
import json

# Initialize Firebase
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()


def serialize_firestore_data(data):
    """
    Convert Firestore special types into JSON serializable format
    """
    if isinstance(data, dict):
        return {k: serialize_firestore_data(v) for k, v in data.items()}

    elif isinstance(data, list):
        return [serialize_firestore_data(v) for v in data]

    elif hasattr(data, "isoformat"):
        return data.isoformat()

    return data


def read_collection(collection_ref):
    collection_data = {}

    docs = collection_ref.stream()

    for doc in docs:
        doc_data = doc.to_dict()
        doc_data = serialize_firestore_data(doc_data)

        # Read subcollections recursively
        subcollections = doc.reference.collections()

        sub_data = {}

        for subcollection in subcollections:
            sub_data[subcollection.id] = read_collection(subcollection)

        if sub_data:
            doc_data["_subcollections"] = sub_data

        collection_data[doc.id] = doc_data

    return collection_data


def export_firestore():
    firestore_data = {}

    collections = db.collections()

    for collection in collections:
        print(f"Reading collection: {collection.id}")

        firestore_data[collection.id] = read_collection(collection)

    return firestore_data


# Export everything
data = export_firestore()

# Save as JSON
with open("firestore_export.json", "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)

print("Firestore exported successfully!")