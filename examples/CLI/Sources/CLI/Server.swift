import Foundation
import Vapor

struct CallbackRequestParameters: Content {
    var error: String?
    var code_uri: String?
}

enum IdentityIssuanceError: Error {
    case identityProviderError(String)
    case invalidIdentityUrl(String)
    case cannotResolveServerPort(String)
    case invalidCallbackRequest
}

func withIdentityIssuanceCallbackServer(_ f: @escaping (_ callbackUrl: URL) throws -> Void) throws -> Result<URL, IdentityIssuanceError> {
    let lock = DispatchSemaphore(value: 0)
    var res: Result<URL, IdentityIssuanceError>? = nil

    let app = Application(.production)
    defer { app.shutdown() }
    app.logger.logLevel = .warning // reduce logging

    // Listen to callback request.
    // Respond with JavaScript snippet for extracting the result from the URL fragment and posting it to '/result/.
    // This is necessary because the browser doesn't send the fragment part to the server.
    // Note that the used format allows us to treat it directly as form data.
    // TODO: Callback (unless it's DTS!) is also invoked on immediate failure. The header is misleading in that case.
    app.get("callback") { _ in
        let body = """
           <!DOCTYPE html>
           <html>
             <head>
               <title>Callback forwarder</title>
               <script>
                 const fragment = window.location.hash;
                 const response = fragment.substring(1);
                 fetch('/callback', {
                   method: 'POST',
                   body: response,
                   headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                 })
                 .then(res => {
                    if (!res.ok) {
                      throw new Error(`HTTP: ${res.status}`);
                    }
                    return res.blob();
                 })
                 .then(res => res.text())
                 .catch(err => `Error: ${err}`)
                 .then(msg => document.getElementById('status').innerHTML = msg);
               </script>
             </head>
             <body>
               <h1>Identity Submitted for Verification</h1>
               <p>Forwarding handler for checking the verification status to the CLI application.</p>
               <p>Status: <span id="status"><i>Sending...</i></span></p>
             </body>
           </html>
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
    // Start temporary server using port picked by the OS.
    try app.server.start(address: .hostname(nil, port: 0))
    defer { app.server.shutdown() }

    // Resolve port picked by the OS.
    guard let port = app.http.server.shared.localAddress?.port else {
        return .failure(IdentityIssuanceError.cannotResolveServerPort(app.http.server.shared.localAddress.debugDescription))
    }

    // Invoke callback with the callback URL.
    try f(URL(string: "http://localhost:\(port)/callback")!)

    // Wait for POST callback.
    lock.wait()
    guard let res else {
        // POST /callback was called but without 'error' nor 'code_uri' fields.
        return .failure(IdentityIssuanceError.invalidCallbackRequest)
    }
    return res
}
