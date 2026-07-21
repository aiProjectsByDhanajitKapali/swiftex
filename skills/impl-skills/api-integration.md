---
name: api-integration
description: Add or update API integrations in the iOS app from an endpoint path or curl by creating endpoint enum cases, service protocol methods, service extensions, and response models using the Decodable macro. Use when the user shares an API path, curl command, HTTP method, or response JSON and wants the app wired to that API.
owner: Dhanajit Kapali
---

# API Integration

Add API integrations following the service pattern. Use this skill when the user wants a new endpoint wired into an existing service or a new service protocol.

## Quick Rules

- If the user provides a `curl`, infer the HTTP method, path, query params, body, and useful headers from it. Do not ask for the method again unless the curl is ambiguous.
- If the user provides only a path/endpoint, ask for the HTTP method if it is not already stated.
- If the response JSON is missing, ask for a sample response JSON and wait.
- Always ask whether this should go into an existing service protocol or a new one.
- Always ask for the parent service if it is not already clear, for example `IDSSService`, `GSSService`, `WalletService`, `CryptoV5Service`, or another service type.
- Always ask whether to also create a JSON-backed mock service in `appUnitTests` for tests or dependency injection.

## Required Inputs

Before implementing, collect these inputs:

1. Request source:
   - endpoint path, or
   - full curl command
2. Response sample JSON
3. Whether to use:
   - an existing service protocol, or
   - a new service protocol
4. Parent service type and target area/folder
5. Whether response caching is needed if the surrounding module uses `saveToDataBase(configuration, data)`
6. Whether to also create a mock service in `appUnitTests` that returns decoded data from local JSON instead of making a network call

## Questions To Ask

Ask only what is missing.

### If curl is provided

- Infer method and request details from curl.
- Ask:
  - sample response JSON, if missing
  - existing protocol or new protocol
  - parent service, if unclear
  - caching requirement, if relevant
  - whether to also add the mock service

### If only endpoint path is provided

- Ask:
  - HTTP method (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`)
  - request parameters/body if not provided
  - sample response JSON
  - existing protocol or new protocol
  - parent service
  - caching requirement, if relevant
  - whether to also add the mock service

## Service Pattern

Follow the local service pattern used in files like:

- `App/Module/IDSS/ADP/Service/IDSSService.swift`
- `App/Module/IDSS/ADP/Service/IDSSRunningTradeService.swift`
- `App/Module/IDSS/ADP/Service/OverviewTab/Overview/OverviewTabService.swift`
- `App/Module/GSSV5/Service/GSSConfigService.swift`

Pattern:

1. Keep the base service separate, for example `IDSSService`.
2. Add a protocol for the feature API.
3. Make the protocol method and implementation return `PNetworkResponse<Model>`, not the bare model.
4. Conform the parent service in an extension:

```swift
protocol SomeFeatureServiceProtocol {
    func fetchSomething(...) async throws -> PNetworkResponse<ResponseModel>
}

extension ParentService: SomeFeatureServiceProtocol {
    func fetchSomething(...) async throws -> PNetworkResponse<ResponseModel> {
        let configuration = ParentServiceEndPoint.someCase(...).configuration
        let result = await App.shared.NW.request(configuration)
        switch result {
        case .success(let data):
            if let response = data.decode(PNetworkResponse<ResponseModel>.self) {
                return response
            } else {
                throw AppError.parsingError
            }
        case .failure(let error):
            throw error
        }
    }
}
```

Preserve nearby naming conventions. Some areas use `...ServiceProtocol`; some older files may not.

Service response rules:

- Always wrap the decoded model in `PNetworkResponse<YourModel>` at the service layer.
- The protocol method signature and the service implementation should both return `PNetworkResponse<YourModel>`.
- Decode `PNetworkResponse<YourModel>.self` from the raw response unless the surrounding module clearly uses a different established pattern.

## Mock Service Pattern

If the user says yes to the mock service:

1. Put the mock implementation in `appUnitTests`.
2. Make the mock conform to the same feature protocol as the real service.
3. Keep the async method signature and return type exactly the same as the real service.
4. Do not call `App.shared.NW.request` from the mock.
5. Inside the mock method, define the JSON fixture as a local `let` multi-line `String`.
6. Convert that local JSON string to `Data`, decode `PNetworkResponse<Model>.self`, and return that decoded response.
7. Fail loudly in tests with a clear error if the local fixture string cannot be converted or decoded.
8. Name the mock consistently with the real service or protocol, for example `MockSomeFeatureService`.

Example shape:

```swift
final class MockSomeFeatureService: SomeFeatureServiceProtocol {
    func fetchSomething(...) async throws -> PNetworkResponse<ResponseModel> {
        let jsonString = """
        {
          "code": 200,
          "message": "success",
          "data": {
            "title": "Example"
          }
        }
        """

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AppError.parsingError
        }

        if let response = jsonData.decode(PNetworkResponse<ResponseModel>.self) {
            return response
        } else {
            throw AppError.parsingError
        }
    }
}
```

Prefer simple fixture injection. If nearby tests already load JSON from a helper or bundle utility, reuse that local test pattern instead of inventing a new one.

## Endpoint Pattern

Add the request to the appropriate endpoint enum, for example:

- `IDSSServiceEndPoint`
- `GSSServiceEndPoint`
- `CryptoV5ServiceEndPoint`

Rules:

- Add a new enum case with associated values for path params, query params, or body params.
- Add the matching `configuration` switch case.
- Use the correct base URL already used by the surrounding enum.
- Use `parameters:` for query/body params.
- Use JSON encoding for body-based requests when needed, for example many `POST`, `PUT`, or `PATCH` calls.
- Do not invent new networking patterns when the local enum already defines one.

## Response Model Rules

When creating models from response JSON:

- If the sample JSON has a top-level `data` key, create the model from the shape inside `data`, not from the outer wrapper object.
- Treat the outer API envelope as `PNetworkResponse<YourModel>` and treat `YourModel` as the payload that lives under `data`.
- Use `@Decodable()`
- Do not add redundant `: Decodable` when using `@Decodable()`
- Make all properties optional
- Keep child types nested inside the parent model where they are used
- Prefer one top-level response data model with nested sub-structs instead of multiple sibling top-level structs
- Use `@CodingKey(...)` only when the JSON key does not match the Swift property name
- Do not add custom `init(from:)` unless the response shape truly cannot be expressed with the macro
- Do not use `@DefaultValue(...)` unless the user explicitly asks for fallback defaults instead of optionals

Example shape:

```swift
@Decodable()
struct SomeResponseData {
    let title: String?
    let items: [Item]?

    @Decodable()
    struct Item {
        let id: String?
        let subtitle: String?
    }
}
```

If the API response looks like:

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "title": "Example",
    "items": [
      {
        "id": "1"
      }
    ]
  }
}
```

Then:

- return type should be `PNetworkResponse<SomeResponseData>`
- `SomeResponseData` should start from the object inside `data`
- do not create a separate top-level model for `code`, `message`, or `data` unless the local module already uses a custom envelope model

## File Placement

Choose placement based on the existing module pattern:

- If an existing service protocol file already owns the feature, update it.
- If no suitable protocol exists, create a new service file near the related tab/feature folder.
- Keep the response model in the same service file when nearby files follow that pattern.
- If the module already separates model files, follow the local pattern instead of forcing a new one.
- Put optional mock services under `appUnitTests`, near related test fixtures or existing mocks for that module.

## Implementation Workflow

1. Collect missing inputs.
2. Identify the parent service and target endpoint enum.
3. Decide whether to update an existing protocol or create a new one.
4. Add the endpoint enum case and `configuration`.
5. Add the protocol method signature.
6. Implement the parent service extension method returning `PNetworkResponse<Model>`.
7. Create the response model using `@Decodable()` with optional nested structs, starting from `data` when the response JSON is wrapped.
8. If requested, add a mock service in `appUnitTests` that conforms to the same protocol and decodes the provided JSON fixture into `PNetworkResponse<Model>`.
9. If the module uses response caching, wire `saveToDataBase(configuration, data)` consistently.
10. Verify naming and folder placement against nearby service files and test mocks.

## What To Avoid

- Do not ask for HTTP method again if a curl already makes it clear.
- Do not proceed without a sample response JSON if a response model must be created.
- Do not create flat sibling model structs when nesting is enough.
- Do not make fields non-optional by default for API response models in this workflow.
- Do not mix service logic into the base service file unless the module already does that nearby.
- Do not ignore local naming conventions for protocol suffixes or folder placement.
- Do not model the outer response envelope as a separate feature response struct if `PNetworkResponse<Payload>` already covers it.
- Do not start the payload model from the full JSON object when the meaningful fields are inside `data`.
- Do not create the mock service unless the user confirms they want it.
- Do not give the mock a different protocol or method signature than the real service.
- Do not put mock-only helpers in the production target when they belong in `appUnitTests`.
- Do not make real network calls from the mock service.

## References

- Base service example: `App/Module/IDSS/ADP/Service/IDSSService.swift`
- Existing protocol + extension: `App/Module/IDSS/ADP/Service/IDSSRunningTradeService.swift`
- Existing protocol + caching pattern: `App/Module/IDSS/ADP/Service/OverviewTab/Overview/OverviewTabService.swift`
- Endpoint enum example: `App/Module/IDSS/ADP/Service/IDSSServiceEndPoint.swift`
