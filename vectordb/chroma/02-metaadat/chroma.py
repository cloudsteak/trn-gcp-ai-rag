import chromadb
chroma_client = chromadb.Client()


collection = chroma_client.create_collection(name="metadata_collection")


collection.add(
    ids=["id1", "id2", "id3", "id4"],
    documents=[
        "Ez egy dokumentum az iPhone-ról",
        "Ez egy dokumentum az iPad-ről",
        "Ez egy dokumentum a MacBook-ról",
        "Ez egy dokumentum a Galaxy Z Fold-ról",
    ],
    metadatas=[
        {"manufacturer": "Apple", "category": "Smartphone"},
        {"manufacturer": "Apple", "category": "Tablet"},
        {"manufacturer": "Apple", "category": "Laptop"},
        {"manufacturer": "Samsung", "category": "Smartphone"},
    ]
)


results = collection.query(
    query_texts=["Ez egy lekérdező dokumentum az Apple termékekről"], # Chroma will embed this for you
    n_results=4 # how many results to return
)
# Eredmények kiíratása a konzolra
print("Eredmények:")
print(results)