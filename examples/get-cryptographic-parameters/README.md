# Example: getCryptographicParameters

Small example program for illustrating how to use the SDK from a consuming application.
The library is included with the version defined as the `main` branch.
Note that this is not a fixed reference and the cache may contain an old revision of that branch.
Real applications should always use a specific version.

The program just creates a `Client` and calls the method `getCryptographicParameters` on it (of last finalized block).
No command line arguments are accepted.
The program assumes to find a running node on localhost port 20000.
The tool `socat` may be used to redirect the requests to a node running on IP `<ip>`, port `<port>`:

```shell
socat TCP-LISTEN:20000,fork TCP:<ip>:<port>
```

The result is printed as a simple struct dump.

## Usage

Build and run the program:

```shell
swift run
```
