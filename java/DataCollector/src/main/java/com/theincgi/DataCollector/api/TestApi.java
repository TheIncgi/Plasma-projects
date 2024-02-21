package com.theincgi.DataCollector.api;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestApi {
	
	@GetMapping(path = "test")
	public ResponseEntity<String> test() {
		return new ResponseEntity<String>("It works.", HttpStatus.OK);
	}
	
}
