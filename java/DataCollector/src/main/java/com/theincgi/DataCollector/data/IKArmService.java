package com.theincgi.DataCollector.data;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class IKArmService {
	
	@Autowired
	IKArmRepo ikArmRepo;
	
	public void record(String model, List<Double> inputs, List<Double> labels) {
		
	}
	
	public void assignToSets() {
		
	}
}
