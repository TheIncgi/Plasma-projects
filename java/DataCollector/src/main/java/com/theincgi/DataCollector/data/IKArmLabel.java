package com.theincgi.DataCollector.data;

import static jakarta.persistence.FetchType.LAZY;

import java.io.Serializable;


import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
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
@Table
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

		@ManyToOne(fetch = LAZY)
		@JoinColumn(name = "uid", referencedColumnName = "uid", insertable = false, updatable = false)
		private IKArmSample sample;
		
		@OrderColumn(nullable = false, updatable = false)
		private int pos;
	}
	
	@EmbeddedId
	private Pk pk;
	
	@Column(nullable = false)
	private float value;
}
