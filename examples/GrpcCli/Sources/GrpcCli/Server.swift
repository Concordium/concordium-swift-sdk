import Foundation
import Vapor

struct IdentityIssuanceResult: Content {
    var error: String?
    var code_uri: String?
}

enum CallbackServerError: Error {
    case error(String)
}

func withIdentityIssuanceCallbackServer(port: Int, _ f: @escaping (Int) throws -> Void) throws -> Result<String, CallbackServerError>? {
    let lock = DispatchSemaphore(value: 0)
    var res: Result<String, CallbackServerError>?

    // TODO: Disable (or simplify/prettify) logging?
    let app = Application()
    defer { app.server.shutdown() }

    app.http.server.configuration.port = port

    // Listen to callback request.
    // Respond with JavaScript snippet for extracting the result from the URL fragment and posting it to '/result/.
    // Note that the used format allows us to treat it directly as form data.
    app.get("callback") { _ in
        let body = """
           <script>
           const fragment = window.location.hash;
           const response = fragment.substring(1);
           fetch('/result', {
             method: 'POST',
             body: response,
             headers: {'Content-Type': 'application/x-www-form-urlencoded'},
           })
           .then(() => document.getElementById('content').style.display = 'block');
           </script>
           <body id="content" style="display:none">
             <h1>Response from Identity Provider sent back to the application</h1>
             You may close this window.
           </h1>
        """
        let r = Response(status: .ok, body: .init(string: body))
        r.headers.contentType = .html
        return r
    }
    // Listen for result shipped by JavaScript snippet above.
    app.post("result") { req in
        defer { lock.signal() }
        let content = try req.content.decode(IdentityIssuanceResult.self)
        if let errMsg = content.error {
            res = .failure(CallbackServerError.error(errMsg))
        }
        if let url = content.code_uri {
            res = .success(url)
        }
        return "OK"
    }
    try app.server.start()
    try f(port)
    lock.wait()
    return res
}
