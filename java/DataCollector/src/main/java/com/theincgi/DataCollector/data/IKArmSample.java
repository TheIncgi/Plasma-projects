package com.theincgi.DataCollector.data;

import static jakarta.persistence.CascadeType.ALL;
import static jakarta.persistence.FetchType.EAGER;
import static jakarta.persistence.FetchType.LAZY;

import java.util.List;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table
@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@EqualsAndHashCode
public class IKArmSample {
	
	@Id
	@GeneratedValue
	private long uid;
	
	@Column(name="dataset", nullable = false)
	@Enumerated(EnumType.ORDINAL)
	private Dataset dataset;
	
	@OneToMany(mappedBy = "pk.sample", cascade = ALL, fetch = EAGER, orphanRemoval = true)
	List<IKArmFeature> features;
	
	@OneToMany(mappedBy = "pk.sample", cascade = ALL, fetch = EAGER, orphanRemoval = true)
	List<IKArmLabel> labels;
	
	@ManyToOne(fetch = LAZY)
	IKArmModel label;
	
	public enum Dataset {
		TRAIN, VALIDATION, TEST
	}
	
}
