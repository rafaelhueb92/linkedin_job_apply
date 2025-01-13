import pytest
import app
from unittest.mock import patch, Mock

@pytest.fixture
def mock_env():
    """Fixture to mock environment variables."""
    with patch.dict('os.environ', {"LINKEDIN_API_TOKEN": "fake-token"}):
        yield

@pytest.fixture
def mock_requests_post():
    """Fixture to mock the requests.post function."""
    with patch('requests.post') as mock_post:
        yield mock_post

def test_lambda_handler_success(mock_env, mock_requests_post):
    """Test the lambda_handler function for a successful case."""
    mock_requests_post.return_value = Mock(status_code=200, json=lambda: {"elements": [
        {"id": "job1", "applicationType": "SIMPLE"},
        {"id": "job2", "applicationType": "NOT_SIMPLE"}
    ]})
    
    event = {}
    context = {}
    response = app.lambda_handler(event, context)
    
    assert response["statusCode"] == 200
    assert response["message"] == "Applied to jobs successfully."
    mock_requests_post.assert_any_call(
        "https://api.linkedin.com/v2/jobSearch",
        json={"keywords": ["Python", "Node.js"], "jobTypes": ["FULL_TIME"], "description": "relocation"},
        headers={
            "Authorization": "Bearer fake-token",
            "Content-Type": "application/json"
        }
    )
    mock_requests_post.assert_any_call(
        "https://api.linkedin.com/v2/jobs/job1/apply",
        headers={
            "Authorization": "Bearer fake-token",
            "Content-Type": "application/json"
        }
    )

def test_search_jobs(mock_env, mock_requests_post):
    """Test the search_jobs function."""
    mock_requests_post.return_value = Mock(status_code=200, json=lambda: {"elements": [{"id": "job1"}, {"id": "job2"}]})
    
    headers = {
        "Authorization": "Bearer fake-token",
        "Content-Type": "application/json"
    }
    criteria = {
        "keywords": ["Python", "Node.js"],
        "jobTypes": ["FULL_TIME"],
        "description": "relocation"
    }
    jobs = app.search_jobs(headers, criteria)
    
    assert len(jobs) == 2
    assert jobs[0]["id"] == "job1"
    assert jobs[1]["id"] == "job2"

def test_apply_to_jobs(mock_env, mock_requests_post):
    """Test the apply_to_jobs function."""
    mock_requests_post.return_value = Mock(status_code=200)
    
    headers = {
        "Authorization": "Bearer fake-token",
        "Content-Type": "application/json"
    }
    jobs = [
        {"id": "job1", "applicationType": "SIMPLE"},
        {"id": "job2", "applicationType": "NOT_SIMPLE"}
    ]
    app.apply_to_jobs(headers, jobs)
    
    mock_requests_post.assert_called_once_with(
        "https://api.linkedin.com/v2/jobs/job1/apply",
        headers=headers
    )

def test_search_jobs_error(mock_env, mock_requests_post):
    """Test the search_jobs function with an API error."""
    mock_requests_post.return_value = Mock(status_code=400, raise_for_status=Mock(side_effect=Exception("API error")))
    
    headers = {
        "Authorization": "Bearer fake-token",
        "Content-Type": "application/json"
    }
    criteria = {
        "keywords": ["Python", "Node.js"],
        "jobTypes": ["FULL_TIME"],
        "description": "relocation"
    }
    
    with pytest.raises(Exception, match="API error"):
        app.search_jobs(headers, criteria)

def test_apply_to_jobs_error(mock_env, mock_requests_post):
    """Test the apply_to_jobs function with an API error."""
    mock_requests_post.return_value = Mock(status_code=400, raise_for_status=Mock(side_effect=Exception("Apply error")))
    
    headers = {
        "Authorization": "Bearer fake-token",
        "Content-Type": "application/json"
    }
    jobs = [{"id": "job1", "applicationType": "SIMPLE"}]
    
    with pytest.raises(Exception, match="Apply error"):
        app.apply_to_jobs(headers, jobs)
