package com.theincgi.DataCollector.data;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.theincgi.DataCollector.data.IKArmSample.Dataset;

@Service
public class IKArmService {
	
	public static final float TRAIN_PERCENT = .6f;
	public static final float TEST_PERCENT = .2f;
	public static final float VALIDATE_PERCENT = .2f;
	
	@Autowired
	IKArmRepo ikArmRepo;
	
	public IKArmModel computeModelIfAbsent(String modelName) {
		var optModel = ikArmRepo.findByName(modelName);
		
		if(optModel.isEmpty()) {
			var tmp = new IKArmModel();
			tmp.setName(modelName);
			return ikArmRepo.save(tmp);
		} else {
			return optModel.get();
		}
	}
	
	public void record(String modelName, List<Float> inputs, List<Float> labels) {
		var model = computeModelIfAbsent(modelName);
		
		IKArmSample sample = new IKArmSample();
		sample.setDataset(Dataset.TRAIN);
		model.samples.add(sample);
		
		int pos = 0;
		for(var f : inputs)
			sample.getFeatures().add(new IKArmFeature(new IKArmFeature.Pk(sample, pos++), f));
		
		pos = 0;
		for(var l : labels)
			sample.getLabels().add(new IKArmLabel(new IKArmLabel.Pk(sample, pos++), l));
		
		ikArmRepo.save(model);
	}
	
	public void assignToSets() {
		
	}
}
