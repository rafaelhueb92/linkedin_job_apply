import os
import requests

LINKEDIN_API_TOKEN = os.getenv("LINKEDIN_API_TOKEN")
LINKEDIN_API_URL = os.getenv("LINKEDIN_API_URL")

def lambda_handler(event, context):
    headers = {
        "Authorization": f"Bearer {LINKEDIN_API_TOKEN}",
        "Content-Type": "application/json"
    }
    
    search_criteria = {
        "keywords": ["Python", "Node.js"],
        "jobTypes": ["FULL_TIME"],
        "description": "relocation"
    }
    
    jobs = search_jobs(headers, search_criteria)
    apply_to_jobs(headers, jobs)
    return {"statusCode": 200, "message": "Applied to jobs successfully."}

def search_jobs(headers, criteria):
    response = requests.post("https://{LINKEDIN_API_URL}/jobSearch", json=criteria, headers=headers)
    response.raise_for_status()
    return response.json().get("elements", [])

def apply_to_jobs(headers, jobs):
    for job in jobs:
        if job.get("applicationType") == "SIMPLE":
            apply_response = requests.post(
                f"https://{LINKEDIN_API_URL}/jobs/{job['id']}/apply", headers=headers)
            apply_response.raise_for_status()
