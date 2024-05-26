from locust import FastHttpUser, task, between

class NoteUser(FastHttpUser):
    # wait_time = between(1, 2)


    @task
    def no_db_endpoint(self):
        self.client.get("/api/no_db_endpoint/")

    @task
    def no_db_endpoint2(self):
        self.client.get("/api/no_db_endpoint2/")