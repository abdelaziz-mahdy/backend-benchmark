from locust import HttpUser, task, between

class NoteUser(HttpUser):
    wait_time = between(1, 2)

    @task
    def write_note(self):
        self.client.post("/api/notes/", json={
            "title": "Sample Note",
            "content": "This is a note content."
        })

    @task
    def read_notes(self):
        self.client.get("/api/notes/")
        
    @task
    def no_db_endpoint(self):
        self.client.get("/api/notes/no_db_endpoint/")

    @task
    def no_db_endpoint2(self):
        self.client.get("/api/notes/no_db_endpoint2/")