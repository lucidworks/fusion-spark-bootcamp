import requests
import json

signals_resource_path = "signals.json"
catalog_resource_path = "catalog.csv"
proxy_url = "http://localhost:8764/api"
proxy_api_url = "{}/apollo".format(proxy_url)

app = "sig_reg"
collection = "sig_reg"
headers = {"Content-type": "application/json"}


def create_admin_session():
    """
    Creates an Session that has been authenticated to the proxy
    """
    headers = {"Content-type": "application/json"}
    data = {'username': "admin", 'password': "password123"}

    session = requests.Session()
    resp = session.post("{0}/session".format(proxy_url), data=json.dumps(data), headers=headers)
    assert resp.status_code == 201, "Expected 201, got {0}\n{1}".format(resp.status_code, resp.content)
    return session


def assert_status(resp, expected_status=200, extra_message=None):
    """
    Checks a Requests response for a given status. Prints the response text on failure
    """
    if extra_message is not None:
        message = "{}, expected {}, found {}. Response text: {}. Url: {}"
        args = [extra_message, expected_status, resp.status_code, resp.text.encode("utf-8"), resp.url.encode("utf-8")]
    else:
        message = "Expected {}, found {}. Response text: {}. Url: {}"
        args = [expected_status, resp.status_code, resp.text.encode("utf-8"), resp.url.encode("utf-8")]

    assert resp.status_code == expected_status, message.format(*args)


def create_app(admin_session):
    print("Creating app {}".format(app))
    resp = admin_session.post("{}/apps".format(proxy_api_url), json={"id": app, "name": app, "description": "dev"})


def create_collection(admin_session):
    print("Creating collection {}".format(collection))
    resp = admin_session.post("{}/collections".format(proxy_api_url), json={"id": collection}, headers=headers)
    assert_status(resp)


def index_signals(admin_session):
    signals_endpoint = "{}/query/{}/signals?commit=true".format(proxy_api_url, collection)
    signals = list()
    print("Indexing signals from {}".format(signals_resource_path))
    data_json = json.load(open(signals_resource_path))
    for query in data_json:
        docs = data_json[query]["signals"]
        for doc in docs:
            signal = {"type": "click", "params": {"query": query, "docId": doc["docId"], "count": doc["count"]}}
            signals.append(signal)
    resp = admin_session.post(signals_endpoint, json=signals, headers=headers)
    assert_status(resp, expected_status=204)


def index_catalog(admin_session):
    index_endpoint = "{0}/index-pipelines/{1}/collections/{1}/index?fusion-rda-id=test-doc".format(proxy_api_url, collection)
    resp = admin_session.post(index_endpoint, data=open(catalog_resource_path), headers={"Content-type": "text/csv"})


def run_aggregation(admin_session):
    default_aggr_id = "{}_click_signals_aggregation".format(collection)
    print("Running aggregation {}".format(default_aggr_id))
    job_url = "{}/spark/jobs/{}".format(proxy_api_url, default_aggr_id)
    aggr_coll = "{}_signals_aggr".format(collection)
    resp = admin_session.post(job_url, headers=headers)
    assert_status(resp)
    print(resp.json())


if __name__ == "__main__":
    admin_session = create_admin_session()
    create_app(admin_session)
    index_catalog(admin_session)
    index_signals(admin_session)
    run_aggregation(admin_session)

