function GOAP_Sensor() constructor {
    x = 0; y = 0; radius = 64;
    target = noone;

    timer_interval = 32;
    timer = new Timer(self.timer_interval);

    self.timer.on_timer_stop = function() {
        update_target_position();
        self.timer.start();
    };

    target_position      = new Vector2();
    target_last_position = new Vector2();

    get_target_position = function() {
        if self.target == noone {
            self.target_position.x = undefined;
            self.target_position.y = undefined;
        } else {
            self.target_position.x = self.target.x;
            self.target_position.y = self.target.y;
        }
    };

    is_target_in_range = function() {
        if self.target == noone { return false; }
        self.get_target_position();
        return bool(point_distance(self.x, self.y, self.target_position.x, self.target_position.y) <= self.radius);
    };

    on_target_changed = function() {};

    update_target_position = function() {
        if self.target == noone { return; }
        self.get_target_position();
        if self.is_target_in_range() && bool(!self.target_position.is_equal(self.target_last_position) || self.target_last_position.is_equal(new Vector2())) {
            self.target_last_position.x = self.target_position.x;
            self.target_last_position.y = self.target_position.y;
            self.on_target_changed();
        }
    };

    start  = function() { self.timer.start();  };
    update = function() { self.timer.tick();   };
    stop   = function() { self.timer.cancel(); };
}
