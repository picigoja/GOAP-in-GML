/// @desc Ensures Animus_SensorHub prevents duplicates and respects provided memory.
function test_animus_sensorhub_add_sensor__prevents_duplicates() {
    var testcase = scr_test_case("Animus_SensorHub add_sensor prevents duplicates");
    var memory = new Animus_Memory();
    var hub = new Animus_SensorHub(undefined, undefined, undefined, memory);
    var sensor = scr_test_fixture_sensor_stub();

    hub.add_sensor(sensor);
    hub.add_sensor(sensor);
    testcase.expect_equal(array_length(hub.sensors), 1, "adding duplicate sensor should be ignored");

    var external_memory = new Animus_Memory();
    hub.tick(external_memory, 0.6);
    testcase.expect_true(external_memory.has("sensor.last_value"), "tick should use provided memory when explicit");

    hub.remove_sensor(sensor);
    testcase.expect_equal(array_length(hub.sensors), 0, "remove_sensor should drop sensor");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_SensorHub";
    return result;
}
