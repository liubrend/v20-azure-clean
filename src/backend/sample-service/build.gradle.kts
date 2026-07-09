// sample-service: domain microservice. RESTful CRUD over Azure SQL (JPA + Liquibase)
// plus an Azure Blob Storage integration. Unit tests (JUnit 5 + Mockito) need no DB;
// the Testcontainers MSSQL integration test lives in a separate `integrationTest`
// source set so the L2 `test` gate stays Docker-free.

sourceSets {
    create("integrationTest") {
        java.srcDir("src/integrationTest/java")
        resources.srcDir("src/integrationTest/resources")
        compileClasspath += sourceSets["main"].output + configurations["testRuntimeClasspath"]
        runtimeClasspath += output + compileClasspath
    }
}

val integrationTestImplementation: Configuration by configurations.getting {
    extendsFrom(configurations["testImplementation"])
}
configurations["integrationTestRuntimeOnly"].extendsFrom(configurations["testRuntimeOnly"])

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-validation")

    // Azure SQL Database (Microsoft SQL Server dialect) + schema migrations.
    runtimeOnly("com.microsoft.sqlserver:mssql-jdbc")
    implementation("org.liquibase:liquibase-core")

    // Azure Blob Storage.
    implementation("com.azure:azure-storage-blob:12.35.0")

    testImplementation("org.springframework.boot:spring-boot-starter-test")

    // Integration test: real SQL Server via Testcontainers (separate source set).
    integrationTestImplementation("org.springframework.boot:spring-boot-testcontainers")
    integrationTestImplementation("org.testcontainers:junit-jupiter")
    integrationTestImplementation("org.testcontainers:mssqlserver")
}

val integrationTest = tasks.register<Test>("integrationTest") {
    description = "Runs integration tests (needs a Docker daemon)."
    group = "verification"
    testClassesDirs = sourceSets["integrationTest"].output.classesDirs
    classpath = sourceSets["integrationTest"].runtimeClasspath
    useJUnitPlatform()
    shouldRunAfter(tasks.named("test"))
}
