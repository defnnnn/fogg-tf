import os
from chalice import Chalice

f = open(os.path.join(os.path.dirname(__file__), 'chalicelib', '.app-name'))
nm_app = f.read().strip()
f.close()

app = Chalice(app_name=nm_app)
app.debug = True

@app.route("/%s" % nm_app, methods=['POST'])
def hello():
    return {'hello': 'world'}

@app.route("/%s/{ps+}" % nm_app, methods=['POST'])
def hello_all():
    return {
        'uri_params': app.current_request.uri_params
    }
