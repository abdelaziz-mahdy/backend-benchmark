from locust import FastHttpUser, task, between

class NoteUser(FastHttpUser):

    @task
    def write_note(self):
        self.client.post("/note/createNote/", json={
            "note":{
            "title": "Sample Note",
            "content": "This is a note content."
        }})

    @task
    def read_notes(self):
        self.client.post("/note/getAllNotes/")

