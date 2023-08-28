curl -v -X POST -H "Content-Type: application/json" -d "{\"last_name\":\"Germano\",\"first_name\":\"Adri\",\"address\":\"Main street 70\",\"zip\":19703,\"city\":\"Rio\",\"phone\":\"++410323861920\"}" http://127.0.0.1:8080/api/customers

curl -X POST --json "{\"last_name\":\"Germano\",\"first_name\":\"Adriana\",\"address\":\"Main street 70\",\"zip\":19703,\"city\":\"Rio\"}" http://127.0.0.1:8080/api/customers

curl http://127.0.0.1:8080/api/customers

curl -X DELETE http://127.0.0.1:8080/api/customers/1