.PHONY: fmt
fmt:
	swift package plugin --allow-writing-to-package-directory swiftformat ./examples

.PHONY: generate-grpc
generate-grpc:
	protoc --proto_path=./concordium-grpc-api --grpc-swift_opt='Client=true,Server=false' --grpc-swift_out=./Sources/Concordium/Generated/GRPC --swift_out=./Sources/Concordium/Generated/GRPC ./concordium-grpc-api/v2/concordium/*.proto
