from locust import FastHttpUser, task

class NoteUser(FastHttpUser):

    @task
    def no_db_endpoint(self):
        with self.client.get("/notes/no_db_endpoint/", catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"Unexpected status code: {response.status_code}. Response: {response.text}")

    @task
    def no_db_endpoint2(self):
        with self.client.get("/notes/no_db_endpoint2/", catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"Unexpected status code: {response.status_code}. Response: {response.text}")
