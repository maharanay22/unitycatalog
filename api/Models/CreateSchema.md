# CreateSchema
## Properties

| Name | Type | Description | Notes |
|------------ | ------------- | ------------- | -------------|
| **name** | **String** | Name of schema, relative to parent catalog. | [default to null] |
| **catalog\_name** | **String** | Name of parent catalog. | [default to null] |
| **comment** | **String** | User-provided free-form text description. | [optional] [default to null] |
| **properties** | **Map** | A map of key-value properties attached to the securable. | [optional] [default to null] |
| **storage\_root** | **String** | Storage root URL for managed storage location of schema. If not set, managed securables under this schema will try to use the storage_location of the parent catalog instead. Example: s3://bucket/ucroot The server stores managed tables and volumes under {storage_root}/__unitystorage/schemas/{schema_id}, and those locations must fit in 2048 bytes in UTF-8. So the normalized root can be at most 1943 bytes in UTF-8 (1943 ASCII characters), or the request fails with INVALID_ARGUMENT. See Storage location limits in the server configuration docs for the cloud storage limits that also apply.  | [optional] [default to null] |

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)

