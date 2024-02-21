package com.theincgi.DataCollector.data;

import java.util.Optional;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface IKArmRepo extends CrudRepository<IKArmModel, Long> {
	public Optional<IKArmModel> findByName(String name);
}
