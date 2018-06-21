import requests
import json
import re

signals_resource_path = "signals.json"
fusion_url = "http://localhost:8765/api/v1"
data_json = json.load(open(signals_resource_path))

app = "sig_reg"
collection_id = "sig_reg"
headers = {"Content-type": "application/json"}

def run_regression():
    for query in data_json:
        relevance_for_query(query, collection_id) 

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

def relevance_for_query(query, pipeline_id):
    expected_docs = data_json[query]["rank"]
    query_url = "{}/query-pipelines/{}/collections/{}/select?q={}&fl=id,score".format(fusion_url, pipeline_id, collection_id, query)
    resp = requests.get(query_url)
    assert_status(resp, expected_status=200)
    solr_response = resp.json()

    # Validate boosts are in right order
    params = solr_response["responseHeader"]["params"]
    assert "boost" in params
    boosts = get_boosts(params["boost"])
    print("Expected order for query '{}' : {}. Search results order {}".format(query, expected_docs, boosts))
    for i, doc_id in enumerate(expected_docs):
        doc_id_at_pos = boosts[i][0]
        assert doc_id == doc_id_at_pos, "Expected order: {}. Search results order {}".format(expected_docs, boosts)

def get_boosts(boost_params):
    """
    Parse docId and boost weight from the boost param. E.g., map(query({!field f='id' v='doc10'}), 0, 0, 1, 81.0).
    This method would return for the above example [(doc10, 81.0), ..]
    """
    boosts = list()
    for boost in boost_params:
        # Extract docID using positive lookbehind assertion
        docid_match = re.search("(?<=v=')\w+", boost)
        if not docid_match:
            pytest.xfail("Did not find docId in boost string {}".format(boost))
        # Extract boost value using lookahead assertion
        bvalue_match = re.search("\d+.\d+(?=\))", boost)
        if not bvalue_match:
            pytest.xfail("Did not find boost value in boost string {}".format(boost))
        doc_id = docid_match.group(0)
        boost_value = float(bvalue_match.group(0))
        boosts.append((doc_id, boost_value))
    boosts.sort(key=lambda x: -x[1])
    return boosts

if __name__ == "__main__":
    run_regression()
