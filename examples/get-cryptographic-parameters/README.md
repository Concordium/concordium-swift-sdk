# Example: getCryptographicParameters

Small example program for illustrating how to use the SDK from a consuming application.

The program just creates a `Client` and calls the method `getCryptographicParameters` on it.
No command line arguments are accepted.
The program assumes to find a running node on localhost port 20000.
The tool `socat` may be used to redirect the requests to a node running on IP `<ip>`, port `<port>`:

```shell
socat TCP-LISTEN:20000,fork TCP:<ip>:<port>
```

## Usage

Build and run the program:

```shell
swift run
```
