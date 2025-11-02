/// @desc Constructs a stub Animus_Sensor derivative for testing.
function scr_test_fixture_sensor_stub() {
    var sensor = new Animus_Sensor(0.5);
    sensor.sense = function(memory) {
        if (is_struct(memory) && Animus_Core.is_callable(memory.write)) {
            memory.write("sensor.last_value", true);
        }
    };
    return sensor;
}
