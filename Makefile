.PHONY: generate-grpc

generate-grpc:
	protoc --proto_path=./concordium-grpc-api --grpc-swift_opt='Client=true,Server=false' --grpc-swift_out=./Sources/concordium-swift-sdk/Grpc --swift_out=./Sources/concordium-swift-sdk/Grpc ./concordium-grpc-api/v2/concordium/*.proto