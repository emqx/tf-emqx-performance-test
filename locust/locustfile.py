import os
import random
from locust import HttpUser, task

class Publish(HttpUser):
    @task
    def publish(self):
        topics_count = int(os.getenv('TOPICS_COUNT', 1000))
        topic = "bench/" + str(random.randint(1, topics_count))
        self.client.post("/mqtt/publish", json={"topic": topic, "clientid": "locust", "payload": "test"}, auth=('perftest', 'perftest'), name="publish")
