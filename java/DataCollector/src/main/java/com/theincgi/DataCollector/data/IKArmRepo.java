package com.theincgi.DataCollector.data;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface IKArmRepo extends CrudRepository<IKArmEntity, Long> {

}
