package com.theincgi.DataCollector.data;

import java.io.Serializable;


import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(indexes = {
		@Index(name = "idx_ikarm_label_uid", columnList = "uid")
})
@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
@EqualsAndHashCode
public class IKArmLabel {
	
	@AllArgsConstructor
	@NoArgsConstructor
	@Getter
	@Setter
	@Embeddable
	@EqualsAndHashCode
	public static class Pk implements Serializable {
		private static final long serialVersionUID = 6338491133067978032L;

		@ManyToOne
		@JoinColumn(name = "uid")
		private IKArmSample sample;
		
		@OrderColumn(nullable = false, updatable = false)
		private int index;
	}
	
	@EmbeddedId
	private Pk pk;
	
	@Column
	private float value;
}
