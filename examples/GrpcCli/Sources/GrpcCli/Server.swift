import Foundation
import Vapor

struct CallbackRequestParameters: Content {
    var error: String?
    var code_uri: String?
}

enum IdentityIssuanceError: Error {
    case identityProviderError(String)
    case invalidIdentityUrl(String)
    case invalidCallbackRequest
}

func withIdentityIssuanceCallbackServer(port: Int, _ f: @escaping (_ port: Int, _ callbackUrl: URL) throws -> Void) throws -> Result<URL, IdentityIssuanceError> {
    let lock = DispatchSemaphore(value: 0)
    var res: Result<URL, IdentityIssuanceError>? = nil

    // TODO: Disable (or simplify/prettify) logging?
    let app = Application()
    defer { app.server.shutdown() }

    // TODO: Can't make OS pick available port?
    app.http.server.configuration.port = port

    // Listen to callback request.
    // Respond with JavaScript snippet for extracting the result from the URL fragment and posting it to '/result/.
    // This is necessary because the browser doesn't send the fragment part to the server.
    // Note that the used format allows us to treat it directly as form data.
    app.get("callback") { _ in
        let body = """
           <script>
           const fragment = window.location.hash;
           const response = fragment.substring(1);
           fetch('/callback', {
             method: 'POST',
             body: response,
             headers: {'Content-Type': 'application/x-www-form-urlencoded'},
           })
           .then(() => document.getElementById('content').style.display = 'block');
           </script>
           <body id="content" style="display:none">
             <h1>Identity Submitted for Verification</h1>
             <p>The handler for observing the verification status has been forwarded to the application.</p>
             <p>Please close this window.</p>
           </h1>
        """
        let r = Response(status: .ok, body: .init(string: body))
        r.headers.contentType = .html
        return r
    }
    // Listen for result shipped by JavaScript snippet above.
    app.post("callback") { req in
        defer { lock.signal() } // unblock main thread after handling request
        let content = try req.content.decode(CallbackRequestParameters.self)
        if let errMsg = content.error {
            res = .failure(IdentityIssuanceError.identityProviderError(errMsg))
        } else if let url = content.code_uri {
            if let identityUrl = URL(string: url) {
                res = .success(identityUrl)
            } else {
                res = .failure(IdentityIssuanceError.invalidIdentityUrl(url))
            }
        }
        return "OK"
    }
    try app.server.start()
    try f(port, URL(string: "http://127.0.0.1:\(port)/callback")!)
    lock.wait() // wait for POST callback (without timeout)
    guard let res else {
        // POST /callback was called but without 'error' nor 'code_uri' fields.
        return .failure(IdentityIssuanceError.invalidCallbackRequest)
    }
    return res
}
