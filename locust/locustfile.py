import os
import random
import string
import logging
from locust import HttpUser, task

class Emqx(HttpUser):
    @task(10)
    def publish(self):
        topics_count = int(os.getenv('TOPICS_COUNT', 1000))
        topic = "bench/" + str(random.randint(1, topics_count))
        payload_size = int(os.getenv('PAYLOAD_SIZE', 256))
        logging.debug(f"Publishing to topic {topic} with payload size {payload_size}")
        payload = ''.join(random.choices(string.ascii_uppercase + string.digits, k=payload_size))
        self.client.post("/mqtt/publish", json={"topic": topic, "clientid": "locust", "payload": payload}, auth=('perftest', 'perftest'))

    @task(10)
    def query_subscriptions(self):
        self.client.get("/subscriptions/dummy", auth=('perftest', 'perftest'))

    @task(10)
    def unsubscribe(self):
        client_batch_size = int(os.getenv('UNSUBSCRIBE_CLIENT_BATCH_SIZE', 100))
        max_client_id = int(os.getenv('MAX_CLIENT_ID', 1000))
        topics_count = int(os.getenv('TOPICS_COUNT', 1000))
        client_prefix_list = os.getenv('CLIENT_PREFIX_LIST', 'a,b,c,d,e').split(',')

        topic = f"bench/{random.randint(1, topics_count)}"
        client_id = random.choice(client_prefix_list) + str(random.randint(1, max_client_id))
        json = [{"topic": topic, "clientid": client_id} for i in range(client_batch_size)]
        self.client.post("/mqtt/unsubscribe_batch", json=json, auth=('perftest', 'perftest'))

    @task(10)
    def del_acl_cache(self):
        max_client_id = int(os.getenv('MAX_CLIENT_ID', 1000))
        client_prefix_list = os.getenv('CLIENT_PREFIX_LIST', 'a,b,c,d,e').split(',')
        client_id = random.choice(client_prefix_list) + str(random.randint(1, max_client_id))
        self.client.delete(f"/clients/{client_id}/acl_cache", auth=('perftest', 'perftest'), name="del_acl_cache")

    @task
    def get_current_metrics(self):
        base_url = os.getenv('EMQX_DASHBOARD_URL', 'http://localhost:18083')
        self.client.get(f"{base_url}/api/v4/monitor/current_metrics", auth=('admin', 'admin'))
