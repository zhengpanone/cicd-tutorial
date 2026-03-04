package com.zp.controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/user")
public class UserController {

    @Value("${app.version::1.0.0}")
    private String version;

    @Value("${HOSTNAME::unknown}")
    private String hostname;

    @GetMapping("/hello")
    public Map<String, Object> hello() {
        Map<String, Object> map = new HashMap<>();
        map.put("message", "Hello Gateway API + Spring Boot");
        map.put("version", version);
        map.put("hostname", hostname);
        return map;
    }

}
