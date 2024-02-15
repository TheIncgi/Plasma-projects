package com.theincgi.DataCollector.data;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

@Entity
@Table
@AllArgsConstructor
@NoArgsConstructor
public class IKArmEntity {
	@Id
	@GeneratedValue
	private long uid;
	
	@Column(name="dataset", nullable = false)
	@Enumerated(EnumType.ORDINAL)
	private Dataset dataset;
	
	
	
	
	public enum Dataset {
		TRAIN, VALIDATION, TEST
	}
}
