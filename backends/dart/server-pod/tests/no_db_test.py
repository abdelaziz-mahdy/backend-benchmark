from locust import FastHttpUser, task, between

class NoteUser(FastHttpUser):

    @task
    def no_db_endpoint(self):
        self.client.post("/note/noDbEndpoint/")
    @task
    def no_db_endpoint2(self):
        self.client.post("/note/noDbEndpoint2/")