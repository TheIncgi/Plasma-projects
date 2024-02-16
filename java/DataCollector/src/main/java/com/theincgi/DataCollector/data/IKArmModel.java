package com.theincgi.DataCollector.data;

import static jakarta.persistence.CascadeType.ALL;
import static jakarta.persistence.FetchType.LAZY;

import java.util.List;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(indexes = {
	@Index(name = "idx_ikarm_model_name", columnList = "name")
})
@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@EqualsAndHashCode
public class IKArmModel {
	
	@Id
	private Long id;
	
	@OneToMany(mappedBy = "label", cascade = ALL, fetch = LAZY, orphanRemoval = true)
	List<IKArmSample> samples;
	
	@Column
	private String name; 
	
}
