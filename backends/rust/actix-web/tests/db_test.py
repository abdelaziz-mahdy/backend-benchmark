from locust import FastHttpUser, task
from locust.exception import RescheduleTaskImmediately

class NoteUser(FastHttpUser):

    @task
    def write_note(self):
        with self.client.post("/notes/", json={
            "title": "Sample Note",
            "content": "This is a note content."
        }, catch_response=True) as response:
            if response.status_code != 200:
                error_message = f"BadStatusCode: '{response.url}', code={response.status_code}, response_text={response.text}"
                response.failure(error_message)
                # Rethrow with added response text
                raise RescheduleTaskImmediately(error_message)

    @task
    def read_notes(self):
        with self.client.get("/notes/", catch_response=True) as response:
            if response.status_code != 200:
                error_message = f"BadStatusCode: '{response.url}', code={response.status_code}, response_text={response.text}"
                response.failure(error_message)
                # Rethrow with added response text
                raise RescheduleTaskImmediately(error_message)
