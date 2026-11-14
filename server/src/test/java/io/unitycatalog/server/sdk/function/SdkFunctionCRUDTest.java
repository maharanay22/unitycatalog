package io.unitycatalog.server.sdk.function;

import static io.unitycatalog.server.utils.TestUtils.CATALOG_NAME;
import static io.unitycatalog.server.utils.TestUtils.SCHEMA_NAME;
import static io.unitycatalog.server.utils.TestUtils.assertApiException;
import static org.assertj.core.api.Assertions.assertThat;

import io.unitycatalog.client.ApiException;
import io.unitycatalog.client.model.ColumnTypeName;
import io.unitycatalog.client.model.CreateFunction;
import io.unitycatalog.client.model.CreateFunctionRequest;
import io.unitycatalog.client.model.CreateSchema;
import io.unitycatalog.client.model.FunctionInfo;
import io.unitycatalog.client.model.FunctionParameterInfos;
import io.unitycatalog.server.base.ServerConfig;
import io.unitycatalog.server.base.catalog.CatalogOperations;
import io.unitycatalog.server.base.function.BaseFunctionCRUDTest;
import io.unitycatalog.server.base.function.FunctionOperations;
import io.unitycatalog.server.base.schema.SchemaOperations;
import io.unitycatalog.server.exception.ErrorCode;
import io.unitycatalog.server.sdk.catalog.SdkCatalogOperations;
import io.unitycatalog.server.sdk.schema.SdkSchemaOperations;
import io.unitycatalog.server.testdatabase.SupportedDatabase;
import io.unitycatalog.server.utils.Constants;
import io.unitycatalog.server.utils.TestUtils;
import java.sql.Statement;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.hibernate.Session;
import org.junit.jupiter.api.Test;

public class SdkFunctionCRUDTest extends BaseFunctionCRUDTest {
  private static final String EMOJI = "😀";

  @Override
  protected CatalogOperations createCatalogOperations(ServerConfig config) {
    return new SdkCatalogOperations(TestUtils.createApiClient(config));
  }

  @Override
  protected SchemaOperations createSchemaOperations(ServerConfig config) {
    return new SdkSchemaOperations(TestUtils.createApiClient(config));
  }

  @Override
  protected FunctionOperations createFunctionOperations(ServerConfig config) {
    return new SdkFunctionOperations(TestUtils.createApiClient(config));
  }

  private FunctionInfo createFunction(String name, String properties) throws ApiException {
    return functionOperations.createFunction(
        new CreateFunctionRequest()
            .functionInfo(
                new CreateFunction()
                    .name(name)
                    .catalogName(CATALOG_NAME)
                    .schemaName(SCHEMA_NAME)
                    .parameterStyle(CreateFunction.ParameterStyleEnum.S)
                    .isDeterministic(true)
                    .externalLanguage("python")
                    .dataType(ColumnTypeName.INT)
                    .fullDataType("INT")
                    .isNullCall(false)
                    .routineBody(CreateFunction.RoutineBodyEnum.EXTERNAL)
                    .routineDefinition("return 1")
                    .securityType(CreateFunction.SecurityTypeEnum.DEFINER)
                    .specificName(name)
                    .sqlDataAccess(CreateFunction.SqlDataAccessEnum.NO_SQL)
                    .inputParams(new FunctionParameterInfos().parameters(List.of()))
                    .properties(properties)));
  }

  private long countPropertyRows(String entityId) {
    try (Session session = hibernateConfigurator.getSessionFactory().openSession()) {
      return session
          .createSelectionQuery(
              "SELECT count(*) FROM PropertyDAO WHERE entityId = :entityId", Long.class)
          .setParameter("entityId", UUID.fromString(entityId))
          .getSingleResult();
    }
  }

  private long countFunctionPropertyRows() {
    try (Session session = hibernateConfigurator.getSessionFactory().openSession()) {
      return session
          .createSelectionQuery(
              "SELECT count(*) FROM PropertyDAO WHERE entityType = :entityType", Long.class)
          .setParameter("entityType", Constants.FUNCTION)
          .getSingleResult();
    }
  }

  @Test
  public void testFunctionPropertiesRoundTrip() throws ApiException {
    createCommonResources();
    String maxLengthKey = "k".repeat(255);
    // Function name, the properties it is created with, and what create, get and list return.
    String[][] cases = {
      {
        "fn_props",
        "{\"tier\": \"gold\", \"owner_team\": \"ml\"}",
        "{\"owner_team\":\"ml\",\"tier\":\"gold\"}"
      },
      {
        "fn_quoted",
        "{\"env.deps\":\"[\\\"requests\\\"]\"}",
        "{\"env.deps\":\"[\\\"requests\\\"]\"}"
      },
      {
        "fn_non_string",
        "{\"attempts\": 3, \"enabled\": true, \"unset\": null, \"nested\": {\"b\": [1, \"c\"]}}",
        "{\"attempts\":\"3\",\"enabled\":\"true\",\"nested\":\"{\\\"b\\\":[1,\\\"c\\\"]}\","
            + "\"unset\":\"null\"}"
      },
      {
        "fn_decimal",
        "{\"amount\": 0.1234567890123456789, \"big\": 1e400, \"price\": 1.50, \"list\": [2.0]}",
        "{\"amount\":\"0.1234567890123456789\",\"big\":\"1E+400\",\"list\":\"[2.0]\","
            + "\"price\":\"1.50\"}"
      },
      {"fn_max_key", "{\"" + maxLengthKey + "\":\"v\"}", "{\"" + maxLengthKey + "\":\"v\"}"},
      {"fn_absent", null, null},
      {"fn_json_null", "null", null},
      {"fn_empty", "{}", null},
      {"fn_empty_string", "", null},
      {"fn_blank", " \n\t", null},
    };
    Map<String, String> expectedByName = new HashMap<>();
    for (String[] c : cases) {
      String name = c[0], properties = c[1], expected = c[2];
      expectedByName.put(name, expected);
      assertThat(createFunction(name, properties).getProperties()).as(name).isEqualTo(expected);
      assertThat(functionOperations.getFunction(CATALOG_NAME + "." + SCHEMA_NAME + "." + name))
          .extracting(FunctionInfo::getProperties)
          .as(name)
          .isEqualTo(expected);
    }
    List<FunctionInfo> listed =
        functionOperations.listFunctions(CATALOG_NAME, SCHEMA_NAME, Optional.empty());
    assertThat(listed).hasSize(cases.length);
    for (FunctionInfo f : listed) {
      assertThat(f.getProperties()).as(f.getName()).isEqualTo(expectedByName.get(f.getName()));
    }
  }

  @Test
  public void testInvalidFunctionPropertiesRejected() throws ApiException {
    createCommonResources();
    for (String properties :
        List.of(
            "not json",
            "[\"a\"]",
            "\"a\"",
            "1",
            "{\"a\":\"b\"} x",
            "{\"a\":\"b\"}{\"c\":\"d\"}",
            "{\"a\":\"1\",\"a\":\"2\"}")) {
      assertApiException(
          () -> createFunction("fn_invalid", properties),
          ErrorCode.INVALID_ARGUMENT,
          "Function properties must be a single JSON object with unique keys");
    }
    for (String key : List.of("k".repeat(256), EMOJI.repeat(256))) {
      assertApiException(
          () -> createFunction("fn_invalid", "{\"" + key + "\":\"v\"}"),
          ErrorCode.INVALID_ARGUMENT,
          "Function property keys cannot be longer than 255 characters");
    }
    for (String properties : List.of("{\"a\\u0000b\":\"v\"}", "{\"k\":\"a\\u0000b\"}")) {
      assertApiException(
          () -> createFunction("fn_invalid", properties),
          ErrorCode.INVALID_ARGUMENT,
          "Function property keys and values cannot contain the NUL character");
    }
    assertApiException(
        () -> createFunction("fn_invalid", "{\"n\":1e9999999999}"),
        ErrorCode.INVALID_ARGUMENT,
        "Function properties contain a number whose exponent is out of range");
    assertThat(functionOperations.listFunctions(CATALOG_NAME, SCHEMA_NAME, Optional.empty()))
        .isEmpty();
    assertThat(countFunctionPropertyRows()).isZero();
  }

  @Test
  public void testPropertyKeyLengthCountsCharacters() throws ApiException {
    createCommonResources();
    String properties = "{\"" + EMOJI.repeat(255) + "\":\"v\"}";
    switch (SupportedDatabase.selected()) {
      case H2 ->
          // H2 counts UTF-16 units, so 255 emoji are 510 units in a varchar(255).
          assertApiException(
              () -> createFunction("fn_max_key", properties),
              ErrorCode.INVALID_ARGUMENT,
              "The database cannot store a key or value of these function properties");
      case POSTGRES_18, MYSQL_8 -> {
        assertThat(createFunction("fn_max_key", properties).getProperties()).isEqualTo(properties);
        assertThat(functionOperations.getFunction(CATALOG_NAME + "." + SCHEMA_NAME + ".fn_max_key"))
            .extracting(FunctionInfo::getProperties)
            .isEqualTo(properties);
      }
    }
  }

  @Test
  public void testPropertyKeysTheDatabaseTreatsAsEqualRejected() throws ApiException {
    createCommonResources();
    String properties = "{\"Tier\":\"a\",\"tier\":\"b\"}";
    switch (SupportedDatabase.selected()) {
      case H2, POSTGRES_18 ->
          assertThat(createFunction("fn_case", properties).getProperties()).isEqualTo(properties);
      case MYSQL_8 -> {
        // The test databases compare text exactly. MySQL's default collation ignores case.
        try (Session session = hibernateConfigurator.getSessionFactory().openSession()) {
          session.doWork(
              connection -> {
                try (Statement statement = connection.createStatement()) {
                  statement.execute(
                      "ALTER TABLE uc_properties MODIFY property_key varchar(255)"
                          + " COLLATE utf8mb4_0900_ai_ci NOT NULL");
                }
              });
        }
        assertApiException(
            () -> createFunction("fn_case", properties),
            ErrorCode.INVALID_ARGUMENT,
            "Function property keys must be unique, and the database treats two of these keys");
        assertThat(functionOperations.listFunctions(CATALOG_NAME, SCHEMA_NAME, Optional.empty()))
            .isEmpty();
        assertThat(countFunctionPropertyRows()).isZero();
      }
    }
  }

  @Test
  public void testDeletingFunctionRemovesItsProperties() throws ApiException {
    String properties = "{\"k1\":\"v1\",\"k2\":\"v2\"}";
    createCommonResources();

    String deletedDirectly = createFunction("fn", properties).getFunctionId();
    assertThat(countPropertyRows(deletedDirectly)).isEqualTo(2);
    functionOperations.deleteFunction(CATALOG_NAME + "." + SCHEMA_NAME + ".fn", true);
    assertThat(countPropertyRows(deletedDirectly)).isZero();

    String deletedWithSchema = createFunction("fn", properties).getFunctionId();
    assertThat(countPropertyRows(deletedWithSchema)).isEqualTo(2);
    schemaOperations.deleteSchema(CATALOG_NAME + "." + SCHEMA_NAME, Optional.of(true));
    assertThat(countPropertyRows(deletedWithSchema)).isZero();

    schemaOperations.createSchema(new CreateSchema().name(SCHEMA_NAME).catalogName(CATALOG_NAME));
    String deletedWithCatalog = createFunction("fn", properties).getFunctionId();
    assertThat(countPropertyRows(deletedWithCatalog)).isEqualTo(2);
    catalogOperations.deleteCatalog(CATALOG_NAME, Optional.of(true));
    assertThat(countPropertyRows(deletedWithCatalog)).isZero();
  }
}
