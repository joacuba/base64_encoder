# Base64 Encoder/Decoder in Zig

This project provides a command-line utility for encoding and decoding Base64 strings, implemented in the Zig programming language. It's built for efficiency and demonstrates basic CLI application development in Zig.

## Features

- Encode a given string to Base64.
- Decode a given Base64 string back to its original form.

## How to Build

To build this project, you need to have Zig installed. Once Zig is set up, navigate to the project's root directory and run:

```bash
zig build
```

This command will compile the project and create an executable in the `zig-out/bin/` directory.

## How to Use

The application can be used from the command line to either encode or decode strings.

### Encoding

To encode a string, use the `-e` or `--encode` flag:

```bash
./zig-out/bin/base64_encoder --encode "Your string to encode"
```

Example:

```bash
./zig-out/bin/base64_encoder -e "Hello, Zig!"
# Output: SGVsbG8sIFppZyE=
```

### Decoding

To decode a Base64 string, use the `-d` or `--decode` flag:

```bash
./zig-out/bin/base64_encoder --decode "SGVsbG8sIFppZyE="
```

Example:

```bash
./zig-out/bin/base64_encoder -d "SGVsbG8sIFppZyE="
# Output: Hello, Zig!
```

## Testing

To run the tests for the project, execute the following command in the project's root directory:

```bash
zig build test
```
