/// @desc Tests Animus_Sensor interval gating logic.
function test_animus_sensor_tick__interval_handling() {
    var testcase = scr_test_case("Animus_Sensor interval handling");
    var sensor = scr_test_fixture_sensor_stub();
    var memory = new Animus_Memory();

    sensor.tick(memory, 0.2);
    testcase.expect_true(!memory.has("sensor.last_value"), "sensor should not trigger before interval");
    sensor.tick(memory, 0.3);
    testcase.expect_true(memory.has("sensor.last_value"), "sensor should trigger once interval reached");

    var rapid_sensor = new Animus_Sensor(0);
    var hit_count = 0;
    rapid_sensor.sense = function(mem) {
        hit_count += 1;
    };
    rapid_sensor.tick(memory, 0.1);
    rapid_sensor.tick(memory, 0.1);
    testcase.expect_true(hit_count >= 2, "zero interval sensor should fire every tick");

    var result = testcase.result();
    result.suite = "unit";
    result.module = "Animus_Sensor";
    return result;
}
