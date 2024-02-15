package com.theincgi.DataCollector.data;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class IKArmService {
	
	@Autowired
	IKArmRepo ikArmRepo;
	
	public void record(String model, double[] inputs, double[] labels) {}
	
}
