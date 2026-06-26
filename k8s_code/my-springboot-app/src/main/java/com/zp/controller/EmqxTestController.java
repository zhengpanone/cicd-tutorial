package com.zp.controller;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import org.eclipse.paho.client.mqttv3.IMqttClient;
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/emqx")
public class EmqxTestController {

    @Value("${emqx.broker-url:tcp://localhost:1883}")
    private String brokerUrl;

    @Value("${emqx.client-id-prefix:my-springboot-app}")
    private String clientIdPrefix;

    @GetMapping("/config")
    public Map<String, Object> config() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("brokerUrl", brokerUrl);
        result.put("clientIdPrefix", clientIdPrefix);
        return result;
    }

    @PostMapping("/publish")
    public Map<String, Object> publish(
            @RequestParam(defaultValue = "cicd-tutorial/emqx/test") String topic,
            @RequestParam(defaultValue = "hello emqx") String payload,
            @RequestParam(defaultValue = "1") int qos) throws Exception {
        IMqttClient client = newClient("publisher");
        try {
            client.connect(connectOptions());
            MqttMessage message = new MqttMessage(payload.getBytes(StandardCharsets.UTF_8));
            message.setQos(qos);
            client.publish(topic, message);
        } finally {
            closeClient(client);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("topic", topic);
        result.put("payload", payload);
        result.put("qos", qos);
        result.put("brokerUrl", brokerUrl);
        result.put("publishedAt", Instant.now().toString());
        return result;
    }

    @PostMapping("/roundtrip")
    public Map<String, Object> roundtrip(
            @RequestParam(defaultValue = "cicd-tutorial/emqx/test") String topic,
            @RequestParam(defaultValue = "hello emqx") String payload,
            @RequestParam(defaultValue = "1") int qos,
            @RequestParam(defaultValue = "5") int timeoutSeconds) throws Exception {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<String> receivedPayload = new AtomicReference<>();

        IMqttClient subscriber = newClient("subscriber");
        IMqttClient publisher = newClient("publisher");
        try {
            subscriber.setCallback(new MqttCallback() {
                @Override
                public void connectionLost(Throwable cause) {
                    // The response reports success only when a message is received before timeout.
                }

                @Override
                public void messageArrived(String arrivedTopic, MqttMessage message) {
                    receivedPayload.set(new String(message.getPayload(), StandardCharsets.UTF_8));
                    latch.countDown();
                }

                @Override
                public void deliveryComplete(IMqttDeliveryToken token) {
                    // Subscriber does not publish messages.
                }
            });

            subscriber.connect(connectOptions());
            subscriber.subscribe(topic, qos);

            publisher.connect(connectOptions());
            MqttMessage message = new MqttMessage(payload.getBytes(StandardCharsets.UTF_8));
            message.setQos(qos);
            publisher.publish(topic, message);

            boolean received = latch.await(timeoutSeconds, TimeUnit.SECONDS);

            Map<String, Object> result = new LinkedHashMap<>();
            result.put("success", received);
            result.put("topic", topic);
            result.put("payload", payload);
            result.put("receivedPayload", receivedPayload.get());
            result.put("qos", qos);
            result.put("timeoutSeconds", timeoutSeconds);
            result.put("brokerUrl", brokerUrl);
            result.put("testedAt", Instant.now().toString());
            return result;
        } finally {
            closeClient(publisher);
            closeClient(subscriber);
        }
    }

    private IMqttClient newClient(String role) throws MqttException {
        String clientId = "%s-%s-%s".formatted(clientIdPrefix, role, UUID.randomUUID());
        return new MqttClient(brokerUrl, clientId, new MemoryPersistence());
    }

    private MqttConnectOptions connectOptions() {
        MqttConnectOptions options = new MqttConnectOptions();
        options.setAutomaticReconnect(true);
        options.setCleanSession(true);
        options.setConnectionTimeout(5);
        return options;
    }

    private void closeClient(IMqttClient client) throws MqttException {
        if (client == null) {
            return;
        }
        try {
            if (client.isConnected()) {
                client.disconnect();
            }
        } finally {
            client.close();
        }
    }
}
