import chromadb
chroma_client = chromadb.PersistentClient(path="./chroma_data")

collection = chroma_client.get_or_create_collection(name="metaadat_collection")


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
    n_results=collection.count(), # how many results to return
    include=["embeddings", "documents", "metadatas", "distances"]
)
# Eredmények kiíratása a konzolra
print("Eredmények:")
print(results)
