from locust import FastHttpUser, task, between

class NoteUser(FastHttpUser):


        
    @task
    def no_db_endpoint(self):
        self.client.get("/api/notes/no_db_endpoint/")

    @task
    def no_db_endpoint2(self):
        self.client.get("/api/notes/no_db_endpoint2/")