# UpdateExternalLocation
## Properties

| Name | Type | Description | Notes |
|------------ | ------------- | ------------- | -------------|
| **url** | **String** | Path URL of the external location. It can be at most 255 characters, or the request fails with INVALID_ARGUMENT. See Storage location limits in the server configuration docs for the cloud storage limits that also apply.  | [optional] [default to null] |
| **credential\_name** | **String** | Name of the storage credential used with this location. Setting it on an external location whose credential was force-deleted repairs the location. | [optional] [default to null] |
| **comment** | **String** | User-provided free-form text description. | [optional] [default to null] |
| **owner** | **String** | Username of the new owner. The user must already exist. | [optional] [default to null] |
| **new\_name** | **String** | New name for the external location. | [optional] [default to null] |
| **force** | **Boolean** | Force the url change even if the external location is in use. | [optional] [default to null] |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)

